require 'knife-cloudformation/cloudformation_base'
require 'knife-cloudformation/utils'

class Chef
  class Knife
    class CloudformationInspect < Knife

      include KnifeCloudformation::KnifeBase
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

      option(:nodes,
        :short => '-N',
        :long => '--nodes',
        :boolean => true,
        :description => 'Display ec2 nodes of stack'
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
        if(config[:nodes])
          do_node_list(stack_name)
        end
      end

      def do_node_list(stack_name)
        nodes = stack(stack_name).nodes.map do |n|
          [n.id, n.public_ip_address]
        end.flatten
        ui.info "Nodes for stack: #{ui.color(stack_name, :bold)}"
        ui.info "#{ui.list(nodes, :uneven_columns_across, 2)}"
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
        content = nil
        attempt_ssh_users.each do |ssh_user_name|
          begin
            content = remote_file_contents(inst_addr, ssh_user_name, remote_path, opts)
            break
          rescue Net::SSH::AuthenticationFailed
            ui.warn "Authentication failed for user: #{ssh_user_name} on instance: #{inst_addr}"
          end
        end
        if(content)
          ui.info "  content of #{remote_path}:"
          ui.info ""
          ui.info content
        else
          ui.error "Failed to retreive content from node at: #{inst_addr}"
        end
      end

      def attempt_ssh_users
        ([ssh_user] + Array(Chef::Config[:knife][:cloudformation][:ssh_attempt_users])).flatten.compact
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
