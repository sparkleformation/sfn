require 'chef/knife/cloudformation_base'

class Chef
  class Knife
    class CloudformationEvents < CloudformationBase

      banner 'knife cloudformation events NAME'

      include CloudformationDefault
      
      option(:poll,
        :short => '-p',
        :long => '--poll',
        :description => 'Poll events while stack status is "in progress"',
        :proc => lambda {|v| Chef::Config[:knife][:cloudformation][:poll] = true }
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

      option(:all_attributes,
        :long => '--all-attributes',
        :description => 'Print all attributes'
      )

      def run
        name = name_args.first
        ui.info "Cloud Formation Events for Stack: #{ui.color(name, :bold)}\n"
        events = stack_events(name)
        output = get_titles(events, :format)
        output += process(events)
        ui.info ui.list(output.flatten, :uneven_columns_across, allowed_attributes.size)
        if(Chef::Config[:knife][:cloudformation][:poll])
          poll_stack(name)
        end
      end
      
      def stack_events(name, continue_from_last=true)
        get_things(name) do
          @_stack_events ||= Mash.new
          if(@_stack_events[name])
            options = {'NextToken' => @_stack_events[name]}
          else
            options = {}
          end
          res = aws_con.describe_stack_events(name, options)
          @_stack_events[name] = res.body['StackToken']
          res.body['StackEvents']
        end
      end

      def poll_stack(name)
        while(stack_in_progress?(name))
          events = stack_events(name)
          output = process(events)
          unless(output.empty?)
            ui.info ui.list(output, :uneven_columns_across, allowed_attributes.size)
          end
          sleep((ENV['CLOUDFORMATION_POLL'] || 15).to_i)
        end
        # One more to see completion
        events = stack_events(name)
        output = process(events)
        unless(output.empty?)
          ui.info ui.list(output, :uneven_columns_across, allowed_attributes.size)
        end
      end

      def stack_in_progress?(name)
        stack_status(name).downcase.include?('in_progress')
      end

      def default_attributes
        %w(Timestamp LogicalResourceId ResourceType ResourceStatus ResourceStatusReason)
      end
    end
  end
end
