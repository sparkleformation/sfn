require 'chef/knife/cloudformation_base'

class Chef
  class Knife
    class CloudformationDestroy < Knife

      include KnifeCloudformation::KnifeBase

      banner 'knife cloudformation destroy NAME'

      def run
        stack_name = name_args.last
        ui.warn "Destroying Cloud Formation: #{ui.color(stack_name, :bold)}"
        ui.confirm 'Destroy this formation'
        destroy_formation!(stack_name)
        poll_stack(stack_name)
        ui.info "  -> Destroyed Cloud Formation: #{ui.color(stack_name, :bold, :red)}"
      end

      def destroy_formation!(stack_name)
        get_things(stack_name, 'Failed to perform destruction') do
          stack(stack_name).destroy
        end
      end

    end
  end
end
