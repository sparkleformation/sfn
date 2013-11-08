require 'knife-cloudformation/cloudformation_base'

class Chef
  class Knife
    class CloudformationDescribe < Knife

      include KnifeCloudformation::KnifeBase

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

      def run
        stack_name = name_args.last
        if(config[:outputs])
          ui.info "Outputs for stack: #{ui.color(stack_name, :bold)}:"
          unless(stack(stack_name).outputs.empty?)
            stack(stack_name).outputs.each do |key, value|
              key = snake(key).to_s.split('_').map(&:capitalize).join(' ')
              ui.info ['  ', ui.color("#{key}:", :bold), value].join(' ')
            end
          else
            ui.info "  #{ui.color('No outputs found')}"
          end
        else
          things_output(stack_name,
            *(config[:resources] ? [get_resources(stack_name), :resources] : [get_description(stack_name), :description])
          )
        end
      end

      def default_attributes
        config[:resources] ? %w(Timestamp ResourceType ResourceStatus) : %w(StackName CreationTime StackStatus DisableRollback)
      end

      def get_description(name)
        get_things(name) do
          [stack(name).raw_stack]
        end
      end

      def get_resources(name)
        get_things(name) do
          stack(name).resources
        end
      end

    end
  end
end
