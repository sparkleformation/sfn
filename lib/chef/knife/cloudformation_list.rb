require 'chef/knife/cloudformation_base'

class Chef
  class Knife
    class CloudformationList < CloudformationBase
      include CloudformationDefault

      banner 'knife cloudformation list NAME'

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

      option(:status,
        :short => '-S STATUS',
        :long => '--status STATUS',
        :description => 'Match given status. Use "none" to disable. Can be used multiple times.',
        :proc => lambda {|val|
          Chef::Config[:knife][:cloudformation][:status] ||= []
          Chef::Config[:knife][:cloudformation][:status].push(val).uniq!
        }
      )

      def run
        things_output(nil, get_list, nil)
      end

      def get_list
        get_things do
          aws.stacks
        end
      end

      def default_attributes
        %w(StackName CreationTime StackStatus TemplateDescription)
      end

    end
  end
end
