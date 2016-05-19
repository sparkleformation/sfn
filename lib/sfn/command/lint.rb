require 'sfn'

module Sfn
  class Command
    # Lint command
    class Lint < Command

      include Sfn::CommandModule::Base
      include Sfn::CommandModule::Template

      # Perform linting
      def execute!
        print_only_original = config[:print_only]
        config[:print_only] = true
        file = load_template_file
        ui.info "#{ui.color("Template Linting (#{provider.connection.provider}): ", :bold)} #{config[:file].sub(Dir.pwd, '').sub(%r{^/}, '')}"
        config[:print_only] = print_only_original

        raw_template = parameter_scrub!(template_content(file))

        if(config[:print_only])
          ui.puts raw_template
        else
          result = lint_template(raw_template)
          if(result == true)
            ui.puts ui.color('  -> VALID', :green, :bold)
          else
            ui.puts ui.color('  -> INVALID', :red, :bold)
            result.each do |failure|
              ui.error "Result Set: #{ui.color(failure[:rule_set].name, :red, :bold)}"
              failure[:failures].each do |f_msg|
                ui.puts "#{ui.color('  *', :red, :bold)} #{f_msg}"
              end
            end
            raise 'Linting failure'
          end
        end
      end

      # Apply linting to given template
      #
      # @param template [Hash]
      # @return [TrueClass, Array<Smash[:rule_set, :failures]>]
      def lint_template(template)
        results = rule_sets.map do |set|
          result = set.apply(template)
          unless(result == true)
            Smash.new(:rule_set => set, :failures => result)
          end
        end.compact
        results.empty? ? true : results
      end

      # @return [Array<Sfn::Lint::RuleSet>]
      def rule_sets
        sets = [config[:lint_directory]].flatten.compact.map do |directory|
          if(File.directory?(directory))
            files = Dir.glob(File.join(directory, '**', '**', '*.rb'))
            files.map do |path|
              begin
                Sfn::Lint.class_eval(
                  IO.read(path), path, 1
                )
              rescue
                ui.warn "Failed to load detected file: #{path}"
                nil
              end
            end
          end
        end.flatten.compact.find_all{|rs| rs.provider == provider.connection.provider}
        unless(config[:local_rule_sets_only])
          sets += Sfn::Lint::RuleSet.get_all(provider.connection.provider)
        end
        if(config[:disabled_rule_set])
          disabled = [config[:disabled_rule_set]].flatten.compact
          sets.delete_if{|i| disabled.include?(i.name.to_s) }
        end
        if(config[:enabled_rule_set])
          enabled = [config[:enabled_rule_set]].flatten.compact
          sets.delete_if{|i| enabled.include?(i.name.to_s) }
        end
        sets
      end

    end
  end
end
