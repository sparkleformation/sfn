require 'pathname'
require 'sparkle_formation'
require 'sfn'

class Sfn
  class Command
    # Validate command
    class Validate < Command

      include Sfn::CommandModule::Base
      incldue Sfn::CommandModule::Template

      def execute!
        file = load_template_file
        file.delete('sfn_nested_stack')
        ui.info "#{ui.color('Cloud Formation Validation: ', :bold)} #{config[:file].sub(Dir.pwd, '').sub(%r{^/}, '')}"
        file = Sfn::Utils::StackParameterScrubber.scrub!(file)
        file = translate_template(file)
        begin
          result = provider.connection.stacks.build(
            :name => 'validation-stack',
            :template => file
          ).validate
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
