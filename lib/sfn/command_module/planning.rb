require 'sfn'
require 'sparkle_formation'

module Sfn
  module CommandModule
    # Planning helpers
    module Planning
      # Create a new planner instance
      #
      # @param [Miasma::Models::Orchestration::Stack]
      # @return [Sfn::Planner]
      def build_planner(stack)
        klass_name = stack.api.class.to_s.split('::').last
        if Planner.const_defined?(klass_name)
          Planner.const_get(klass_name).new(ui, config, arguments, stack)
        else
          warn "Failed to build planner for current provider. No provider implemented. (`#{klass_name}`)"
          nil
        end
      end

      # Display plan result on the UI
      #
      # @param result [Miasma::Models::Orchestration::Stack::Plan]
      def display_plan_information(result)
        ui.info ui.color('Pre-update resource planning report:', :bold)
        unless print_plan_result(result)
          ui.info 'No resources life cycle changes detected in this update!'
        end
        cmd = self.class.to_s.split('::').last.downcase
        ui.confirm "Apply this stack #{cmd}?" unless config[:plan_only]
      end

      # Print plan information to the UI
      #
      # @param info [Miasma::Models::Orchestration::Stack::Plan]
      # @param names [Array<String>] nested names
      def print_plan_result(info, names = [])
        said_any_things = false
        unless Array(info.stacks).empty?
          info.stacks.each do |s_name, s_info|
            result = print_plan_result(s_info, [*names, s_name].compact)
            said_any_things ||= result
          end
        end
        if !names.flatten.compact.empty? || info.name
          said_things = false
          output_name = names.empty? ? info.name : names.join(' > ')
          ui.puts
          ui.puts "  #{ui.color('Update plan for:', :bold)} #{ui.color(names.join(' > '), :blue)}"
          unless Array(info.unknown).empty?
            ui.puts "    #{ui.color('!!! Unknown update effect:', :red, :bold)}"
            print_plan_items(info, :unknown, :red)
            ui.puts
            said_any_things = said_things = true
          end
          unless Array(info.unavailable).empty?
            ui.puts "    #{ui.color('Update request not allowed:', :red, :bold)}"
            print_plan_items(info, :unavailable, :red)
            ui.puts
            said_any_things = said_things = true
          end
          unless Array(info.replace).empty?
            ui.puts "    #{ui.color('Resources to be replaced:', :red, :bold)}"
            print_plan_items(info, :replace, :red)
            ui.puts
            said_any_things = said_things = true
          end
          unless Array(info.interrupt).empty?
            ui.puts "    #{ui.color('Resources to be interrupted:', :yellow, :bold)}"
            print_plan_items(info, :interrupt, :yellow)
            ui.puts
            said_any_things = said_things = true
          end
          unless Array(info.remove).empty?
            ui.puts "    #{ui.color('Resources to be removed:', :red, :bold)}"
            print_plan_items(info, :remove, :red)
            ui.puts
            said_any_things = said_things = true
          end
          unless Array(info.add).empty?
            ui.puts "    #{ui.color('Resources to be added:', :green, :bold)}"
            print_plan_items(info, :add, :green)
            ui.puts
            said_any_things = said_things = true
          end
          unless said_things
            ui.puts "    #{ui.color('No resource lifecycle changes detected!', :green)}"
            ui.puts
            said_any_things = true
          end
        end
        said_any_things
      end

      # Print planning items
      #
      # @param info [Miasma::Models::Orchestration::Stack::Plan] plan
      # @param key [Symbol] key of items
      # @param color [Symbol] color to flag
      def print_plan_items(info, key, color)
        collection = info.send(key)
        max_name = collection.map(&:name).map(&:size).max
        max_type = collection.map(&:type).map(&:size).max
        max_p = collection.map(&:diffs).flatten(1).map(&:name).map(&:to_s).map(&:size).max
        max_o = collection.map(&:diffs).flatten(1).map(&:current).map(&:to_s).map(&:size).max
        collection.each do |val|
          name = val.name
          ui.print ' ' * 6
          ui.print ui.color("[#{val.type}]", color)
          ui.print ' ' * (max_type - val.type.size)
          ui.print ' ' * 4
          ui.print ui.color(name, :bold)
          properties = Array(val.diffs).map(&:name)
          unless properties.empty?
            ui.print ' ' * (max_name - name.size)
            ui.print ' ' * 4
            ui.print "Reason: Updated properties: `#{properties.join('`, `')}`"
          end
          ui.puts
          if config[:diffs]
            unless val.diffs.empty?
              p_name = nil
              val.diffs.each do |diff|
                if !diff.proposed.nil? || !diff.current.nil?
                  p_name = diff.name
                  ui.print ' ' * 8
                  ui.print "#{p_name}: "
                  ui.print ' ' * (max_p - p_name.size)
                  ui.print ui.color("-#{diff.current}", :red) if diff.current
                  ui.print ' ' * (max_o - diff.current.to_s.size)
                  ui.print ' '
                  if diff.proposed == Sfn::Planner::RUNTIME_MODIFIED
                    ui.puts ui.color("+#{diff.current} <Dependency Modified>", :green)
                  else
                    if diff.proposed.nil?
                      ui.puts
                    else
                      ui.puts ui.color("+#{diff.proposed.to_s.gsub('__MODIFIED_REFERENCE_VALUE__', '<Dependency Modified>')}", :green)
                    end
                  end
                end
              end
              ui.puts if p_name
            end
          end
        end
      end
    end
  end
end
