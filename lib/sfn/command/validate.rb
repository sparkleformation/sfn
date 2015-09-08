require 'sparkle_formation'
require 'sfn'

module Sfn
  class Command
    # Validate command
    class Validate < Command

      include Sfn::CommandModule::Base
      include Sfn::CommandModule::Template
      include Sfn::CommandModule::Stack

      def execute!
        print_only_original = config[:print_only]
        config[:print_only] = true
        file = load_template_file
        file.delete('sfn_nested_stack')
        ui.info "#{ui.color("Template Validation (#{provider.connection.provider}): ", :bold)} #{config[:file].sub(Dir.pwd, '').sub(%r{^/}, '')}"
        file = Sfn::Utils::StackParameterScrubber.scrub!(file)
        file = translate_template(file)
        config[:print_only] = print_only_original

        if(config[:print_only])
          ui.puts _format_json(file)
        else
          validate_stack(file, sparkle_collection.get(:template, config[:file])[:name])
        end
      end

      def validate_stack(stack, name)
        resources = stack.fetch('Resources', {})
        nested_stacks = resources.find_all do |r_name, r_value|
          r_value.is_a?(Hash) &&
            provider.connection.data[:stack_types].include?(r_value['Type'])
        end
        nested_stacks.each do |n_name, n_resource|
          validate_stack(n_resource.fetch('Properties', {}).fetch('Stack', {}), "#{name} > #{n_name}")
          n_resource['Properties'].delete('Stack')
        end
        begin
          ui.info "Validating: #{ui.color(name, :bold)}"
          stack = provider.connection.stacks.build(
            :name => 'validation-stack',
            :template => Sfn::Utils::StackParameterScrubber.scrub!(stack)
          )
          result = api_action!(:api_stack => stack) do
            stack.validate
          end
          ui.info ui.color('  -> VALID', :bold, :green)
        rescue => e
          ui.info ui.color('  -> INVALID', :bold, :red)
          ui.fatal e.message
          raise e
        end
      end

    end
  end
end
