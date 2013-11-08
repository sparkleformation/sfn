require 'knife-cloudformation/cloudformation_base'

class Chef
  class Knife
    class CloudformationList < Knife
      include KnifeCloudformation::KnifeBase

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
          aws.aws(:cloud_formation).list_stacks(list_options).body['StackSummaries'].sort do |x,y|
            if(y['CreationTime'].to_s.empty?)
              -1
            elsif(x['CreationTime'].to_s.empty?)
              1
            else
              Time.parse(y['CreationTime'].to_s) <=> Time.parse(x['CreationTime'].to_s)
            end
          end
        end
      end

      def list_options
        status = Chef::Config[:knife][:cloudformation][:status] ||
          KnifeCloudformation::AwsCommons::DEFAULT_STACK_STATUS
        if(status.map(&:downcase).include?('none'))
          filter = {}
        else
          count = 0
          filter = Hash[*(
              status.map do |n|
                count += 1
                ["StackStatusFilter.member.#{count}", n]
              end.flatten
          )]
        end
        filter
      end

      def default_attributes
        %w(StackName CreationTime StackStatus TemplateDescription)
      end

    end
  end
end
