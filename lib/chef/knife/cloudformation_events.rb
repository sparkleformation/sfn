require 'chef/knife/cloudformation_base'

class Chef
  class Knife
    class CloudformationEvents < Knife

      banner 'knife cloudformation events NAME'

      include KnifeCloudformation::KnifeBase

      option(:polling,
        :short => '-p',
        :long => '--[no-]poll',
        :boolean => true,
        :default => false,
        :description => 'Poll events while stack status is "in progress"',
        :proc => lambda {|v| Chef::Config[:knife][:cloudformation][:poll] = v }
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

      option(:poll_delay,
        :short => '-D secs',
        :long => '--poll-delay secs',
        :description => 'Number of seconds to pause between event poll',
        :proc => lambda {|val|
          Chef::Config[:knife][:cloudformation][:poll_delay] = val.to_i
        }
      )

      option(:all_attributes,
        :long => '--all-attributes',
        :description => 'Print all attributes'
      )

      def run
        name = name_args.first
        ui.info "Cloud Formation Events for Stack: #{ui.color(name, :bold)}\n"
        things_output(name, get_events(name), 'events')
        if(Chef::Config[:knife][:cloudformation][:poll])
          while(stack(name).in_progress?)
            sleep(Chef::Config[:knife][:cloudformation][:poll_delay] || 15)
            things_output(nil, get_events(name), 'events', :no_title, :ignore_empty_output)
          end
          # Extra to see completion
          things_output(nil, get_events(name), 'events', :no_title, :ignore_empty_output)
        end
      end

      def get_events(name)
        get_things do
          stack(name).events
        end
      end

      def default_attributes
        %w(Timestamp LogicalResourceId ResourceType ResourceStatus ResourceStatusReason)
      end
    end
  end
end
