require 'knife-cloudformation'

class Chef
  class Knife
    # Cloudformation inspect command
    class CloudformationInspect < Knife

      include KnifeCloudformation::Knife::Base
      include KnifeCloudformation::Utils::Ssher

      banner 'knife cloudformation inspect NAME'

      option(:attribute,
        :short => '-a ATTR',
        :long => '--attribute ATTR',
        :description => 'Dot delimited attribute to view'
      )

      option(:nodes,
        :short => '-N',
        :long => '--[no-]nodes',
        :boolean => true,
        :description => 'Locate all instances'
      )

      option(:instance_failure,
        :short => '-I [LOG_FILE_PATH]',
        :long => '--instance-failure [LOG_FILE_PATH]',
        :descrption => 'Display chef log file (defaults /var/log/chef/client.log)',
        :proc => lambda{|val|
          Chef::Config[:knife][:cloudformation][:failure_log_path] = val
        }
      )

      option(:identity_file,
        :short => '-i IDENTITY_FILE',
        :long => '--identity-file IDENTITY_FILE',
        :description => 'SSH identity file for authentication',
        :proc => lambda{|val|
          Chef::Config[:knife][:cloudformation][:identity_file] = val
        }
      )

      option(:ssh_user,
        :short => '-x SSH_USER',
        :long => '--ssh-user SSH_USER',
        :description => 'SSH username for inspection connect',
        :proc => lambda{|val|
          Chef::Config[:knife][:cloudformation][:ssh_user] = val
        }
      )

      # Run the stack inspection action
      def run
        stack_name = name_args.last
        stack = provider.stacks.get(stack_name)
        ui.info "Stack inspection #{ui.color(stack_name, :bold)}:"
        outputs = [:attribute, :nodes, :instance_failure].map do |key|
          if(config.has_key?(key))
            send("display_#{key}", stack)
            key
          end
        end.compact
        if(outputs.empty?)
          ui.info '  Stack dump:'
          ui.info MultiJson.dump(
            MultiJson.load(
              stack.reload.to_json
            ),
            :pretty => true
          )
        end
      end

      def display_instance_failure(stack)
        instances = stack.resources.all.find_all do |resource|
          resource.state.to_s.end_with?('failed')
        end.map do |resource|
          # If compute instance, simply expand
          if(resource.within?(:compute, :servers))
            resource.instance
          # If a waitcondition, check for instance ID
          elsif(resource.type.to_s.downcase.end_with?('waitcondition'))
            if(resources.status_reason.to_s.include?('uniqueId'))
              srv_id = resources.status_reason.split(' ').last.strip
              provider.connection.api_for(:compute).servers.get(srv_id)
            end
          end
        end.compact
        if(instance.empty?)
          ui.error 'Failed to locate any failed instances'
        else
          log_path = Chef::Config[:knife][:cloudformation].fetch(
            :failure_log_path, '/var/log/chef/client.log'
          )
          opts = ssh_key ? {:key => ssh_key} : {}
          instances.each do |instance|
            ui.info "  -> Log inspect for #{instance.id}:"
            address = instance.addresses_public.map do |address|
              if(address.version == 4)
                address.address
              end
            end
            if(address)
              ssh_attempt_users.each do |user|
                begin
                  ui.info remote_file_contents(address, user, log_path, opts)
                  break
                rescue Net::SSH::AuthenticationFailed
                  ui.warn "Authentication failed for user #{user} on instance #{address}"
                rescue => e
                  ui.error "Failed to retrieve log: #{e}"
                  break
                end
              end
            end
          end
        end
      end

      # Users to attempt SSH connection
      #
      # @return [Array<String>] usernames for ssh connect attempt
      def ssh_attempt_users
        base_user = Chef::Config[:knife][:cloudformation][:ssh_user] ||
          Chef::Config[:knife][:ssh_user] ||
          ENV['USER']
        [base_user, Chef::Config[:knife][:cloudformation][:ssh_attempt_users]].flatten.compact
      end

      def ssh_key
        Chef::Config[:knife][:cloudformation][:identity_file] ||
          Chef::Config[:knife][:identity_file]
      end

      def display_attribute(stack)
        attr = config[:attribute].split('.').inject(stack) do |memo, key|
          args = key.scan(/\(([^)]*)\)/).flatten.first.to_s
          if(args)
            args = args.split(',').map{|a| a.to_i.to_s == a ? a.to_i : a}
            key = key.split('(').first
          end
          if(memo.public_methods.include?(key.to_sym))
            if(args.size == 1 && args.first.to_s.start_with?('&'))
              memo.send(key, &args.first.slice(2, args.first.size).to_sym)
            else
              memo.send(*[key, args].flatten.compact)
            end
          else
            raise NoMethodError.new "Invalid attribute requested! (#{memo.class}##{key})"
          end
        end
        ui.info "  Attribute Lookup -> #{config[:attribute]}:"
        ui.info MultiJson.dump(
          MultiJson.load(
            MultiJson.dump(attr)
          ),
          :pretty => true
        )
      end

      def display_nodes(stack)
        asg_nodes = Smash[
          stack.resources.all.find_all do |resource|
            resource.within?(:auto_scale, :groups)
          end.map do |group_resource|
            asg = group_resource.expand
            [
              asg.name,
              Smash[
                asg.servers.map(&:expand).map{|s|
                  [s.id, Smash.new(
                      :name => s.name,
                      :addresses => s.addresses.map(&:address)
                  )]
                }
              ]
            ]
          end
        ]
        compute_nodes = Smash[
          stack.resources.all.find_all do |resource|
            resource.within?(:compute, :servers)
          end.map do |srv|
            srv = srv.instance
            [srv.id, Smash.new(
                :name => srv.name,
                :addresses => srv.addresses.map(&:address)
            )]
          end
        ]
        unless(asg_nodes.empty?)
          ui.info '  AutoScale Group Instances:'
          ui.info MultiJson.dump(asg_nodes, :pretty => true)
        end
        unless(compute_nodes.empty?)
          ui.info '  Compute Instances:'
          ui.info MultiJson.dump(compute_nodes, :pretty => true)
        end
      end

    end
  end
end
