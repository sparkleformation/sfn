require 'chef/knife/cloudformation_base'

class Chef
  class Knife
    class CloudformationDestroy < CloudformationBase

      include CloudformationDefault
      
      banner 'knife cloudformation destroy NAME[ NAME ...]'

      def run
        name_args.each do |stack_name|
          ui.warn "Destroying Cloud Formation: #{ui.color(stack_name, :bold)}"
          ui.confirm 'Destroy this formation'
          destroy_formation!(stack_name)
          ui.info "  -> Destroyed Cloud Formation: #{ui.color(stack_name, :bold, :red)}"
        end
      end

      def destroy_formation!(stack_name)
        get_things(stack_name, 'Failed to perform destruction') do
          aws_con.delete_stack(stack_name)
        end
      end
      
    end
  end
end
