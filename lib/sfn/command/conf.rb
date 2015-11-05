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
        if(config[:generate])
          ui.puts
          ui.info 'Generating .sfn configuration file..'
          generate_config!
          ui.info "Generation of .sfn configuration file #{ui.color('complete!', :green, :bold)}"
        end
      end

      def generate_config!
        if(File.exists?('.sfn'))
          ui.warn 'Existing .sfn configuration file detected!'
          ui.confirm 'Overwrite current .sfn configuration file?'
        end
        run_action 'Writing .sfn file' do
          File.open('.sfn', 'w') do |file|
            file.write SFN_CONFIG_CONTENTS
          end
          nil
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

      SFN_CONFIG_CONTENTS = <<-EOF
# This is an auto-generated configuration file for
# the sfn CLI. To view all available configuration
# options, please see:
# http://www.sparkleformation.io/docs/sfn/configuration.html
Configuration.new do
  apply_nesting 'deep'
  processing true
  options do
    on_failure 'nothing'
    notification_topics []
    capabilities ['CAPABILITY_IAM']
    tags do
      creator ENV['USER']
    end
  end
  # nesting_bucket 'BUCKET_NAME'
  credentials do
    provider :aws
    aws_access_key_id ENV['AWS_ACCESS_KEY_ID']
    aws_secret_access_key ENV['AWS_SECRET_ACCESS_KEY']
    aws_region ENV['AWS_REGION']
    aws_bucket_region ENV['AWS_REGION']
    # aws_sts_role_arn ENV['AWS_STS_ROLE_ARN']
  end
end
EOF


    end
  end
end
