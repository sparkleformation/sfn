require 'sfn'

module Sfn
  class Command
    # Inspect command
    class Inspect < Command

      include Sfn::CommandModule::Base
      include Sfn::Utils::Ssher

      # Run the stack inspection action
      def execute!
        name_required!
        stack_name = name_args.last
        stack = provider.connection.stacks.get(stack_name)
        ui.info "Stack inspection #{ui.color(stack_name, :bold)}:"
        outputs = api_action!(:api_stack => stack) do
          [:attribute, :nodes, :load_balancers, :instance_failure].map do |key|
            if(config.has_key?(key))
              send("display_#{key}", stack)
              key
            end
          end.compact
        end
        if(outputs.empty?)
          ui.info '  Stack dump:'
          ui.puts MultiJson.dump(
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
            if(resource.status_reason.to_s.include?('uniqueId'))
              srv_id = resource.status_reason.split(' ').last.strip
              provider.connection.api_for(:compute).servers.get(srv_id)
            end
          end
        end.compact
        if(instances.empty?)
          ui.error 'Failed to locate any failed instances'
        else
          log_path = config[:failure_log_path]
          if(log_path.to_s.empty?)
            log_path = '/var/log/chef/client.log'
          end
          opts = ssh_key ? {:keys => [ssh_key]} : {}
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
                  ui.info remote_file_contents(address.first, user, log_path, opts)
                  break
                rescue Net::SSH::AuthenticationFailed
                  ui.warn "Authentication failed for user #{user} on instance #{address}"
                rescue => e
                  ui.error "Failed to retrieve log: #{e}"
                  _debug e
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
        [config[:ssh_user], config[:ssh_attempt_users], ENV['USER']].flatten.compact.uniq
      end

      def ssh_key
        config[:identity_file]
      end

      def display_attribute(stack)
        [config[:attribute]].flatten.compact.each do |stack_attribute|
          attr = stack_attribute.split('.').inject(stack) do |memo, key|
            args = key.scan(/\(([^\)]*)\)/).flatten.first.to_s
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
          ui.puts MultiJson.dump(
            MultiJson.load(
              MultiJson.dump(attr)
            ),
            :pretty => true
          )
        end
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
                asg.servers.map(&:expand).compact.map{|s|
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
            if(srv)
              [srv.id, Smash.new(
                :name => srv.name,
                :addresses => srv.addresses.map(&:address)
              )]
            end
          end.compact
        ]
        unless(asg_nodes.empty?)
          ui.info '  AutoScale Group Instances:'
          ui.puts MultiJson.dump(asg_nodes, :pretty => true)
        end
        unless(compute_nodes.empty?)
          ui.info '  Compute Instances:'
          ui.puts MultiJson.dump(compute_nodes, :pretty => true)
        end
      end

      def display_load_balancers(stack)
        load_balancers = Smash[
          stack.resources.all.find_all do |resource|
            resource.within?(:load_balancer, :balancers)
          end.map do |lb|
            exp_lb = lb.expand
            lb_pub_addrs = exp_lb.public_addresses.nil? ? nil : exp_lb.public_addresses.map(&:address)
            lb_priv_addrs = exp_lb.private_addresses.nil? ? nil : exp_lb.private_addresses.map(&:address)
            [lb.id, Smash.new(
              :name => exp_lb.name,
              :state => exp_lb.state,
              :public_addresses => lb_pub_addrs,
              :private_addresses => lb_priv_addrs,
              :server_states => exp_lb.server_states
            ).delete_if {|k,v| v.nil?}
            ]
          end
        ]
        unless load_balancers.empty?
          ui.info '  Load Balancer Instances:'
          ui.puts MultiJson.dump(load_balancers, :pretty => true)
        end
      end

    end
  end
end
