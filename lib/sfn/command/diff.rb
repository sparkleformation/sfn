require "sparkle_formation"
require "sfn"
require "hashdiff"

module Sfn
  class Command
    # Diff command
    class Diff < Command
      include Sfn::CommandModule::Base
      include Sfn::CommandModule::Template
      include Sfn::CommandModule::Stack

      # Diff the stack with existing stack
      def execute!
        name_required!
        name = name_args.first

        begin
          stack = provider.stack(name)
        rescue Miasma::Error::ApiError::RequestError
          stack = nil
        end

        if stack
          config[:print_only] = true
          file = load_template_file
          file = parameter_scrub!(file.dump)

          ui.info "#{ui.color("SparkleFormation:", :bold)} #{ui.color("diff", :blue)} - #{name}"
          ui.puts

          diff_stack(stack, MultiJson.load(MultiJson.dump(file)).to_smash)
        else
          ui.fatal "Failed to locate requested stack: #{ui.color(name, :red, :bold)}"
          raise "Failed to locate stack: #{name}"
        end
      end

      # @todo needs updates for better provider compat
      def diff_stack(stack, file, parent_names = [])
        stack_template = stack.template
        nested_stacks = Hash[
          file.fetch("Resources", file.fetch("resources", {})).find_all do |name, value|
            value.fetch("Properties", {})["Stack"]
          end
        ]
        nested_stacks.each do |name, value|
          n_stack = stack.nested_stacks(false).detect do |ns|
            ns.data[:logical_id] == name
          end
          if n_stack
            diff_stack(n_stack, value["Properties"]["Stack"], [*parent_names, stack.data.fetch(:logical_id, stack.name)].compact)
          end
          file["Resources"][name]["Properties"].delete("Stack")
        end

        ui.info "#{ui.color("Stack diff:", :bold)} #{ui.color((parent_names + [stack.data.fetch(:logical_id, stack.name)]).compact.join(" > "), :blue)}"

        stack_diff = Hashdiff.diff(stack.template, file)

        if config[:raw_diff]
          ui.info "Dumping raw template diff:"
          require "pp"
          pp stack_diff
        else
          added_resources = stack_diff.find_all do |item|
            item.first == "+" && item[1].match(/Resources\.[^.]+$/)
          end
          removed_resources = stack_diff.find_all do |item|
            item.first == "-" && item[1].match(/Resources\.[^.]+$/)
          end
          modified_resources = stack_diff.find_all do |item|
            item[1].start_with?("Resources.") &&
              !item[1].end_with?("TemplateURL") &&
              !item[1].include?("Properties.Parameters")
          end - added_resources - removed_resources

          if added_resources.empty? && removed_resources.empty? && modified_resources.empty?
            ui.info "No changes detected"
            ui.puts
          else
            unless added_resources.empty?
              ui.info ui.color("Added Resources:", :green, :bold)
              added_resources.each do |item|
                ui.print ui.color("  -> #{item[1].split(".").last}", :green)
                ui.puts " [#{item[2]["Type"]}]"
              end
              ui.puts
            end

            unless modified_resources.empty?
              ui.info ui.color("Modified Resources:", :yellow, :bold)
              m_resources = Hash.new.tap do |hash|
                modified_resources.each do |item|
                  _, key, path = item[1].split(".", 3)
                  hash[key] ||= {}
                  prefix, a_key = path.split(".", 2)
                  hash[key][prefix] ||= []
                  matched = hash[key][prefix].detect do |i|
                    i[:path] == a_key
                  end
                  if matched
                    if item.first == "-"
                      matched[:original] = item[2]
                    else
                      matched[:new] = item[2]
                    end
                  else
                    hash[key][prefix] << Hash.new.tap do |info|
                      info[:path] = a_key
                      case item.first
                      when "~"
                        info[:original] = item[2]
                        info[:new] = item[3]
                      when "+"
                        info[:new] = item[2]
                      else
                        info[:original] = item[2]
                      end
                    end
                  end
                end
              end.to_smash(:sorted).each do |key, value|
                ui.puts ui.color("  - #{key}", :yellow) + " [#{stack.template["Resources"][key]["Type"]}]"
                value.each do |prefix, items|
                  ui.puts ui.color("    #{prefix}:", :bold)
                  items.each do |item|
                    original = item[:original].nil? ? ui.color("(none)", :yellow) : ui.color(item[:original].inspect, :red)
                    new_val = item[:new].nil? ? ui.color("(deleted)", :red) : ui.color(item[:new].inspect, :green)
                    ui.puts "      #{item[:path]}: #{original} -> #{new_val}"
                  end
                end
              end
              ui.puts
            end

            unless removed_resources.empty?
              ui.info ui.color("Removed Resources:", :red, :bold)
              removed_resources.each do |item|
                ui.print ui.color("  <- #{item[1].split(".").last}", :red)
                ui.puts " [#{item[2]["Type"]}]"
              end
              ui.puts
            end

            run_callbacks_for(:after_stack_diff,
                              :diff => stack_diff,
                              :diff_info => {
                                :added => added_resources,
                                :modified => modified_resources,
                                :removed => removed_resources,
                              },
                              :api_stack => stack,
                              :new_template => file)
          end
        end
      end
    end
  end
end
