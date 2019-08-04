require "sparkle_formation"
require "sfn"

module Sfn
  class Command
    # Trace command
    class Trace < Command
      include Sfn::CommandModule::Base
      include Sfn::CommandModule::Template
      include Sfn::CommandModule::Stack

      # Print the requested template
      def execute!
        config[:sparkle_dump] = true
        config[:print_only] = true
        file = load_template_file

        if !file.is_a?(SparkleFormation)
          raise "Cannot trace non-SparkleFormation template"
        else
          writer = proc do |audit_log, indent = ""|
            audit_log.each do |record|
              header = "#{indent}-> "
              header << ui.color(record.type.to_s.capitalize, :bold)
              header << " - #{record.name}"
              source = "#{indent} |  source: "
              if record.location.line > 0
                source << "#{record.location.path} @ #{record.location.line}"
              else
                source << ui.color(record.location.path, :yellow)
              end
              origin = "#{indent} |  caller: "
              if record.caller.line > 0
                origin << "#{record.caller.path} @ #{record.caller.line}"
              else
                origin << ui.color(record.caller.path, :yellow)
              end
              duration = "#{indent} |  duration: "
              if record.compile_duration
                duration << Kernel.sprintf("%0.4f", record.compile_duration)
                duration << "s"
              else
                duration < "N/A"
              end
              ui.info header
              ui.info source
              ui.info origin
              ui.info duration
              if record.audit_log.count > 0
                writer.call(record.audit_log, indent + " |")
              end
            end
          end
          ui.info ui.color("Trace information:", :bold)
          writer.call(file.audit_log)
        end
      end
    end
  end
end
