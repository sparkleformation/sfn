require 'chef/knife/cloudformation_base'

class Chef
  class Knife
    class CloudformationDescribe < CloudformationBase
      include CloudformationDefault

      banner 'knife cloudformation describe NAME'
      
      option(:resources,
        :short => '-r',
        :long => '--resources',
        :description => 'Display resources for stack(s)'
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
        name_args.each do |stack|
          things_output(stack,
            *(config[:resources] ? [get_resources(stack), :resources] : [get_description(stack), :description])
          )
        end
      end

      def default_attributes
        config[:resources] ? %w(Timestamp ResourceType ResourceStatus) : %w(StackName CreationTime StackStatus DisableRollback)
      end

      def get_description(stack)
        get_things(stack) do
          [aws_con.describe_stacks('StackName' => stack).body['Stacks'].first]
        end
      end
      
      def get_resources(stack)
        get_things(stack) do
          aws_con.describe_stack_resources('StackName' => stack).body['StackResources']
        end
      end
      
    end
  end
end
