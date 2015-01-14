require 'sfn'

module Sfn
  class Command
    # Events command
    class Events < Command

      include Sfn::CommandModule::Base

      # Run the events list action
      def execute!
        name = name_args.first
        ui.info "Cloud Formation Events for Stack: #{ui.color(name, :bold)}\n"
        stack = provider.connection.stacks.get(name)
        last_id = nil
        if(stack)
          events = get_events(stack)
          things_output(name, events, 'events')
          last_id = events.last ? events.last[:id] : nil
          if(config[:poll])
            cycle_events = true
            while(cycle_events)
              cycle_events = stack.in_progress?
              sleep(config[:poll_delay])
              stack.events.reload
              events = get_events(stack, last_id)
              unless(events.empty?)
                last_id = events.last[:id]
                things_output(nil, events, 'events', :no_title, :ignore_empty_output)
              end
              nest_stacks = stack.resources.all.find_all do |resource|
                resource.state.to_s.end_with?('in_progress') &&
                  resource.type == 'AWS::CloudFormation::Stack'
              end
              if(nest_stacks)
                nest_stacks.each do |nest_stack|
                  begin
                    poll_stack(nest_stack.id)
                    ui.info "Complete event listing for nested stack (#{nest_stack.name})"
                  rescue => e
                    ui.warn "Error encountered on event listing for nested stack - #{e} (#{nest_stack.name})"
                  end
                end
              end
              stack.reload
            end
            # Extra to see completion
            things_output(nil, get_events(stack, last_id), 'events', :no_title, :ignore_empty_output)
          end
        else
          ui.fatal "Failed to locate requested stack: #{ui.color(name, :bold, :red)}"
          raise "Failed to locate stack: #{name}!"
        end
      end

      # Fetch events from stack
      #
      # @param stack [Miasma::Models::Orchestration::Stack]
      # @param last_id [String] only return events after this ID
      # @return [Array<Hash>]
      def get_events(stack, last_id=nil)
        get_things do
          stack_events = stack.events.all
          if(last_id)
            start_index = stack_events.index{|event| event.id == last_id}
            events = stack_events.slice(0, start_index.to_i)
          else
            events = stack_events
          end
          events.map do |event|
            Smash.new(event.attributes)
          end
        end
      end

      # @return [Array<String>] default attributes for events
      def default_attributes
        %w(time resource_logical_id resource_status resource_status_reason)
      end
    end
  end
end
