require 'knife-cloudformation'

class Chef
  class Knife
    # Cloudformation destroy command
    class CloudformationDestroy < Knife

      include KnifeCloudformation::Knife::Base

      banner 'knife cloudformation destroy NAME [NAME]'

      option(:polling,
        :long => '--[no-]poll',
        :description => 'Enable stack event polling.',
        :boolean => true,
        :default => true,
        :proc => lambda {|val| Chef::Config[:knife][:cloudformation][:poll] = val }
      )

      # Run the stack destruction action
      def run
        stacks = name_args.sort
        plural = 's' if stacks.size > 1
        ui.warn "Destroying Cloud Formation#{plural}: #{ui.color(stacks.join(', '), :bold)}"
        ui.confirm "Destroy formation#{plural}"
        stacks.each do |stack_name|
          stack = provider.stacks.get(stack_name)
          if(stack)
            stack.destroy
          else
            ui.warn "Failed to locate requested stack: #{ui.color(stack_name, :bold)}"
          end
        end
        if(config[:polling])
          if(stacks.size == 1)
            provider.fetch_stacks
            poll_stack(stacks.first)
          else
            ui.error "Stack polling is not available when multiple stack deletion is requested!"
          end
        end
        ui.info "  -> Destroyed Cloud Formation#{plural}: #{ui.color(stacks.join(', '), :bold, :red)}"
      end

    end
  end
end
