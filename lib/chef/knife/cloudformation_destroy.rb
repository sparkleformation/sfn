require 'chef/knife/cloudformation_base'

class Chef
  class Knife
    class CloudformationDestroy < Knife

      include KnifeCloudformation::KnifeBase

      banner 'knife cloudformation destroy NAME [NAME]'

      option(:polling,
        :long => '--[no-]poll',
        :description => 'Enable stack event polling.',
        :boolean => true,
        :default => true,
        :proc => lambda {|val| Chef::Config[:knife][:cloudformation][:poll] = val }
      )

      def run
        stacks = name_args.sort
        plural = 's' if stacks.size > 1
        ui.warn "Destroying Cloud Formation#{plural}: #{ui.color(stacks.join(', '), :bold)}"
        ui.confirm "Destroy formation#{plural}"
        stacks.each do |stack_name|
          destroy_formation!(stack_name)
          ui.info "Destroy request sent for stack: #{ui.color(stack_name, :bold)}"
        end
        if(config[:polling])
          stacks.each do |stack_name|
            poll_stack(stack_name)
          end
          ui.info "  -> Destroyed Cloud Formation#{plural}: #{ui.color(stacks.join(', '), :bold, :red)}"
        end
      end

      def destroy_formation!(stack_name)
        get_things(stack_name, 'Failed to perform destruction') do
          stack(stack_name).destroy
        end
      end

    end
  end
end
