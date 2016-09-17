require 'sfn'

module Sfn
  class Command
    # Config command
    class Conf < Command

      include Sfn::CommandModule::Base

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
  #   Set style of stack nesting
  apply_nesting 'deep'
  #   Enable processing of SparkleFormation templates
  processing true
  #   Provider specific options used when creating
  #   new stacks. Options defined here are AWS specific.
  options do
    on_failure 'nothing'
    notification_topics []
    capabilities ['CAPABILITY_IAM']
    tags do
      creator ENV['USER']
    end
  end
  #   Name of bucket in object store to hold nested
  #   stack templates
  # nesting_bucket 'BUCKET_NAME'
  #   Prefix used on generated template path prior to storage
  #   in the object store
  # nesting_prefix 'nested-templates'
  #   Remote provider credentials
  credentials do
    #  Remote provider name (:aws, :azure, :google, :open_stack, :rackspace)
    provider :aws
    #  AWS credentials information
    aws_access_key_id ENV['AWS_ACCESS_KEY_ID']
    aws_secret_access_key ENV['AWS_SECRET_ACCESS_KEY']
    aws_region ENV['AWS_REGION']
    aws_bucket_region ENV['AWS_REGION']
    # aws_sts_role_arn ENV['AWS_STS_ROLE_ARN']
    #  Eucalyptus related additions
    # api_endpoint ENV['EUCA_ENDPOINT']
    # euca_compat 'path'
    # ssl_enabled false
    #  Azure credentials information
    azure_tenant_id ENV['AZURE_TENANT_ID']
    azure_client_id ENV['AZURE_CLIENT_ID']
    azure_subscription_id ENV['AZURE_SUBSCRIPTION_ID']
    azure_client_secret ENV['AZURE_CLIENT_SECRET']
    azure_region ENV['AZURE_REGION']
    azure_blob_account_name ENV['AZURE_BLOB_ACCOUNT_NAME']
    azure_blob_secret_key ENV['AZURE_BLOB_SECRET_KEY']
    #  Defaults to "miasma-orchestration-templates"
    azure_root_orchestration_container ENV['AZURE_ROOT_ORCHESTRATION_CONTAINER']
    #  OpenStack credentials information
    open_stack_identity_url ENV['OPENSTACK_IDENTITY_URL']
    open_stack_username ENV['OPENSTACK_USERNAME']
    open_stack_user_id ENV['OPENSTACK_USER_ID']
    open_stack_password ENV['OPENSTACK_PASSWORD']
    open_stack_token ENV['OPENSTACK_TOKEN']
    open_stack_region ENV['OPENSTACK_REGION']
    open_stack_tenant_name ENV['OPENSTACK_TENANT_NAME']
    open_stack_domain ENV['OPENSTACK_DOMAIN']
    open_stack_project ENV['OPENSTACK_PROJECT']
    #  Rackspace credentials information
    rackspace_api_key ENV['RACKSPACE_API_KEY']
    rackspace_username ENV['RACKSPACE_USERNAME']
    rackspace_region ENV['RACKSPACE_REGION']
    #  Google Cloud Deployment Manager credentials
    google_service_account_email ENV['GOOGLE_SERVICE_ACCOUNT_EMAIL']
    google_service_account_private_key ENV['GOOGLE_SERVICE_ACCOUNT_PRIVATE_KEY']
    google_project ENV['GOOGLE_PROJECT']
  end
end
EOF


    end
  end
end
