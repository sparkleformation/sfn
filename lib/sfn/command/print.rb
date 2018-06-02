require "sparkle_formation"
require "sfn"

module Sfn
  class Command
    # Print command
    class Print < Command
      include Sfn::CommandModule::Base
      include Sfn::CommandModule::Template
      include Sfn::CommandModule::Stack

      # Print the requested template
      def execute!
        config[:print_only] = true
        file = load_template_file

        output_content = parameter_scrub!(template_content(file))
        if config[:yaml]
          require "yaml"
          output_content = YAML.dump(output_content)
        else
          output_content = format_json(output_content)
        end

        if config[:write_to_file]
          unless File.directory?(File.dirname(config[:write_to_file]))
            run_action "Creating parent directory" do
              FileUtils.mkdir_p(File.dirname(config[:write_to_file]))
              nil
            end
          end
          run_action "Writing template to file - #{config[:write_to_file]}" do
            File.write(config[:write_to_file], output_content)
            nil
          end
        else
          ui.puts output_content
        end
      end
    end
  end
end
