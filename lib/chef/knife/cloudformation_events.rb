require 'knife-cloudformation'

class Chef
  class Knife
    # Cloudformation list command
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

      # Run the events list action
      def run
        name = name_args.first
        ui.info "Cloud Formation Events for Stack: #{ui.color(name, :bold)}\n"
        stack = provider.stacks.find{|s| s.stack_name == name}
        last_id = nil
        if(stack)
          events = get_events(stack)
          things_output(name, events, 'events')
          last_id = events.last[:id]
          if(Chef::Config[:knife][:cloudformation][:poll])
            while(stack(name).in_progress?)
              sleep(Chef::Config[:knife][:cloudformation][:poll_delay] || 15)
              stack.events.reload
              events = get_events(stack, last_id)
              last_id = events.last[:id]
              things_output(nil, events, 'events', :no_title, :ignore_empty_output)
            end
            # Extra to see completion
            things_output(nil, get_events(stack, last_id), 'events', :no_title, :ignore_empty_output)
          end
        else
          ui.fatal "Failed to locate requested stack: #{ui.color(name, :bold, :red)}"
          exit -1
        end
      end

      # Fetch events from stack
      #
      # @param stack [Fog::Orchestration::Stack]
      # @param last_id [String] only return events after this ID
      # @return [Array<Hash>]
      def get_events(stack, last_id=nil)
        get_things do
          if(last_id)
            start_index = stack.events.index{|event| event.id == last_id}
            events = stack.events.slice(start_index.to_i, stack.events.length)
          else
            events = stack.events
          end
          events.map do |event|
            Mash.new(event.attributes)
          end
        end
      end

      # @return [Array<String>] default attributes for events
      def default_attributes
        %w(event_time logical_resource_id resource_status resource_status_reason)
      end
    end
  end
end
