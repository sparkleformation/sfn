require 'knife-cloudformation'

class Chef
  class Knife
    # Cloudformation list command
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

      # Run the list command
      def run
        things_output(nil, get_list, nil)
      end

      # Get the list of stacks to display
      #
      # @return [Array<Hash>]
      def get_list
        get_things do
          provider.stacks.map do |stack|
            Mash.new(stack.attributes)
          end.sort do |x, y|
            if(y[:creation_time].to_s.empty?)
              -1
            elsif(x[:creation_time].to_s.empty?)
              1
            else
              Time.parse(y['creation_time'].to_s) <=> Time.parse(x['creation_time'].to_s)
            end
          end
        end
      end

      # @return [Array<String>] default attributes to display
      def default_attributes
        %w(stack_name creation_time stack_status description)
      end

    end
  end
end
