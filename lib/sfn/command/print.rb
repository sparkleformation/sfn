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

        j = _format_json(file)
        begin
            File.write(config[:write_file], j) if config[:write_file]
        rescue Exception => e
          ui.fatal "Failed to write stack: #{e}"
          ui.puts "#{e.class}: #{e}\n#{e.backtrace.join("\n")}"
        end
        ui.puts j
      end

    end
  end
end
