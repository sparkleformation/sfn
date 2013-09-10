require 'chef/knife/cloudformation_base'
require 'knife-cloudformation/utils'

class Chef
  class Knife
    class CloudformationInspect < CloudformationBase
      include CloudformationDefault
      include KnifeCloudformation::Utils::Ssher

      banner 'knife cloudformation inspect NAME'

      option(:instance_failure,
        :short => '-I',
        :long => '--instance-failure',
        :boolean => true,
        :description => 'Display log from failed instance'
      )

      option(:identity_file,
        :short => '-i IDENTITY_FILE',
        :long => '--identity-file IDENTITY_FILE',
        :description => 'The SSH identity file used for authentication',
        :proc => lambda {|val|
          Chef::Config[:knife][:cloudformation][:identity_file] = val
        }
      )

      option(:ssh_user,
        :short => '-x SSH_USER',
        :long => '--ssh-user SSH_USER',
        :description => 'The ssh username',
        :proc => lambda {|val|
          Chef::Config[:knife][:cloudformation][:ssh_user] = val
        }
      )

      def run
        stack_name = name_args.last
        if(config[:instance_failure])
          do_instance_failure(stack_name)
        end
      end

      def do_instance_failure(stack_name)
        event = stack(stack_name).events.detect do |e|
          e['ResourceType'] == 'AWS::CloudFormation::WaitCondition' &&
            e['ResourceStatus'] == 'CREATE_FAILED' &&
            e['ResourceStatusReason'].include?('uniqueId')
        end
        if(event)
          process_instance_failure(stack_name, event)
        else
          ui.error "Failed to discover failed node within stack: #{stack_name}"
          exit 1
        end
      end

      def process_instance_failure(stack_name, event)
        inst_id = event['ResourceStatusReason'].split(' ').last.strip
        inst_addr = aws.aws(:ec2).servers.get(inst_id).public_ip_address
        ui.info "Displaying stack #{ui.color(stack_name, :bold)} failure on instance #{ui.color(inst_id, :bold)}"
        opts = ssh_key ? {:keys => [ssh_key]} : {}
        remote_path = '/var/log/cfn-init.log'
        content = remote_file_contents(inst_addr, ssh_user, remote_path, opts)
        ui.info "  content of #{remote_path}:"
        ui.info ""
        ui.info content
      end

      def ssh_user
        Chef::Config[:knife][:cloudformation][:ssh_user] ||
          Chef::Config[:knife][:ssh_user] ||
          ENV['USER']
      end

      def ssh_key
        Chef::Config[:knife][:cloudformation][:identity_file] ||
          Chef::Config[:knife][:identity_file]
      end

    end
  end
end
