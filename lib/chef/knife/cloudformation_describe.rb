require 'knife-cloudformation'

class Chef
  class Knife
    # Cloudformation describe command
    class CloudformationDescribe < Knife

      include KnifeCloudformation::Knife::Base

      banner 'knife cloudformation describe NAME'

      option(:resources,
        :short => '-r',
        :long => '--resources',
        :description => 'Display resources for stack'
      )
      option(:outputs,
        :short => '-o',
        :long => '--outputs',
        :description => 'Display output for stack'
      )
      option(:attribute,
        :short => '-a ATTR',
        :long => '--attribute ATTR',
        :description => 'Attribute to print. Can be used multiple times.',
        :proc => lambda {|val|
          Chef::Config[:knife][:cloudformation][:attributes] ||= []
          Chef::Config[:knife][:cloudformation][:attributes].push(val).uniq!
        }
      )
      option(:all,
        :long => '--all-attributes',
        :description => 'Print all attributes'
      )

      # information available
      unless(defined?(AVAILABLE_DISPLAYS))
        AVAILABLE_DISPLAYS = [:resources, :outputs]
      end

      # Run the stack describe action
      def run
        stack_name = name_args.last
        stack = provider.stacks.find{|s| s.stack_name = stack_name}
        if(stack)
          display = [].tap do |to_display|
            AVAILABLE_DISPLAYS.each do |display_option|
              if(config[display_option])
                to_display << display_option
              end
            end
          end
          display = AVAILABLE_DISPLAYS.dup if display.empty?
          display.each do |display_method|
            self.send(display_method, stack)
            ui.info ''
          end
        else
          ui.fatal "Failed to find requested stack: #{ui.color(stack_name, :bold, :red)}"
          exit -1
        end
      end

      # Display resources
      #
      # @param stack [Fog::Orchestration::Stack]
      def resources(stack)
        stack_resources = stack.resources.map do |resource|
          Mash.new(resource.attributes)
        end
        things_output(stack.stack_name, stack_resources, :resources)
      end

      # Display outputs
      #
      # @param stack [Fog::Orchestration::Stack]
      def outputs(stack)
        ui.info "Outputs for stack: #{ui.color(stack.stack_name, :bold)}:"
        unless(stack.outputs.empty?)
          stack.outputs.each do |key, value|
            key = snake(key).to_s.split('_').map(&:capitalize).join(' ')
            ui.info ['  ', ui.color("#{key}:", :bold), value].join(' ')
          end
        else
          ui.info "  #{ui.color('No outputs found')}"
        end
      end

      # @return [Array<String>] default attributes
      def default_attributes
        %w(updated_time logical_resource_id resource_type resource_status)
      end

    end
  end
end
