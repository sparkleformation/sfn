require 'sparkle_formation'
require 'sfn'

module Sfn
  class Command
    # Print command
    class Print < Command

      include Sfn::CommandModule::Base
      include Sfn::CommandModule::Template
      include Sfn::CommandModule::Stack

      def execute!
        config[:print_only] = true
        file = load_template_file
        file.delete('sfn_nested_stack')
        file = Sfn::Utils::StackParameterScrubber.scrub!(file)
        file = translate_template(file)

        ui.puts _format_json(file)
      end

    end
  end
end
