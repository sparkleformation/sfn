require 'sfn'

module Sfn
  class Command
    # Config command
    class Conf < Command

      # Run the list command
      def execute!
        ui.info ui.color("Current configuration state:")
        Config::Conf.attributes.sort_by(&:first).each do |k, val|
          if(config.has_key?(k))
            ui.print "  #{ui.color(k, :bold, :green)}: "
            format_value(config[k], '  ')
          end
        end
      end

      def format_value(value, indent='')
        if(value.is_a?(Hash))
          ui.puts
          value.sort_by(&:first).each do |k,v|
            ui.print "#{indent}  #{ui.color(k, :bold)}: "
            format_value(v, indent + '  ')
          end
        elsif(value.is_a?(Array))
          ui.puts
          value.map(&:to_s).sort.each do |v|
            ui.print "#{indent}  "
            format_value(v, indent + '  ')
          end
        else
          ui.puts value.to_s
        end
      end

    end
  end
end
