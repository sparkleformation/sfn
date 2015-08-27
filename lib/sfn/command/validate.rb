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
        file = load_template_file
        file.delete('sfn_nested_stack')
        ui.info "#{ui.color("Template Validation (#{provider.connection.provider}): ", :bold)} #{config[:file].sub(Dir.pwd, '').sub(%r{^/}, '')}"
        file = Sfn::Utils::StackParameterScrubber.scrub!(file)
        file = translate_template(file)

        if(config[:print_only])
          ui.puts _format_json(file)
        else
          begin
            stack = provider.connection.stacks.build(
              :name => 'validation-stack',
              :template => file
            )
            result = api_action!(:api_stack => stack) do
              stack.validate
            end
            ui.info ui.color('  -> VALID', :bold, :green)
          rescue => e
            ui.info ui.color('  -> INVALID', :bold, :red)
            ui.fatal e.message
            failed = true
          end
        end
      end

    end
  end
end
