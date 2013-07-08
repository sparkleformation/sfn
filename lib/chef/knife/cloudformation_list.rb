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
          aws_con.list_stacks(aws_filter_hash).body['StackSummaries']
        end
      end

      def default_attributes
        %w(StackName CreationTime StackStatus TemplateDescription)
      end

      def status_filter
        val = Chef::Config[:knife][:cloudformation][:status] || %w(CREATE_COMPLETE CREATE_IN_PROGRESS UPDATE_IN_PROGRESS UPDATE_COMPLETE_CLEANUP_IN_PROGRESS UPDATE_COMPLETE)
        val.map(&:downcase).include?('none') ? [] : val.map(&:upcase)
      end

      def aws_filter_hash
        hash = Mash.new
        status_filter.each_with_index do |filter, i|
          hash["StackStatusFilter.member.#{i+1}"] = filter
        end
        hash
      end
    end
  end
end
