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
        :default => false,
        :description => 'Locate all instances'
      )

      # Run the stack inspection action
      def run
        stack_name = name_args.last
        stack = provider.stacks.get(stack_name)
        ui.info "Stack inspection #{ui.color(stack_name, :bold)}:"
        outputs = [:attribute, :nodes].map do |key|
          if(config[key])
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
            [srv.id, Smash.new(
                :name => srv.name,
                :addresses => s.addresses.map(&:address)
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
