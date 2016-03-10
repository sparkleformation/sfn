require 'sfn'

module Sfn
  class Command
    # Events command
    class Events < Command

      include Sfn::CommandModule::Base

      # @return [Miasma::Models::Orchestration::Stack]
      attr_reader :stack

      # Run the events list action
      def execute!
        name_required!
        name = name_args.first
        ui.info "Events for Stack: #{ui.color(name, :bold)}\n"
        @seen_events = []
        @stack = provider.stack(name)
        if(stack)
          api_action!(:api_stack => stack) do
            table = ui.table(self) do
              table(:border => false) do
                events = get_events
                row(:header => true) do
                  allowed_attributes.each do |attr|
                    width_val = events.map{|e| e[attr].to_s.length}.push(attr.length).max + 2
                    width_val = width_val > 70 ? 70 : width_val < 20 ? 20 : width_val
                    column attr.split('_').map(&:capitalize).join(' '), :width => width_val
                  end
                end
                events.each do |event|
                  row do
                    allowed_attributes.each do |attr|
                      column event[attr]
                    end
                  end
                end
              end
            end.display
            if(config[:poll])
              while(stack.reload.in_progress?)
                to_wait = config.fetch(:poll_wait_time, 10).to_f
                while(to_wait > 0)
                  sleep(0.1)
                  to_wait -= 0.1
                end
                stack.resources.reload
                table.display
              end
            end
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
      def get_events(*args)
        stack_events = discover_stacks(stack).map do |i_stack|
          i_events = i_stack.events.reload.all
          i_events.map do |e|
            e.attributes.merge(:stack_name => i_stack.name).to_smash
          end
        end.flatten.compact.find_all{|e| e[:time] }.reverse
        stack_events.delete_if{|evt| @seen_events.include?(evt)}
        @seen_events.concat(stack_events)
        unless(@initial_complete)
          stack_events = stack_events.sort_by{|e| e[:time] }
          unless(config[:all_events])
            start_index = stack_events.rindex do |item|
              item[:stack_name] == stack.name &&
                item[:resource_state].to_s.end_with?('in_progress') &&
                item[:resource_status_reason].to_s.downcase.include?('user init')
            end
            if(start_index)
              stack_events.slice!(0, start_index)
            end
          end
          @initial_complete = true
        end
        stack_events
      end

      # Discover stacks defined within the resources of given stack
      #
      # @param stack [Miasma::Models::Orchestration::Stack]
      def discover_stacks(stack)
        @stacks = [stack] + stack.nested_stacks.reverse
      end

      # @return [Array<String>] default attributes for events
      def default_attributes
        %w(stack_name time resource_logical_id resource_status resource_status_reason)
      end

      # @return [Array<String>] allowed attributes for events
      def allowed_attributes
        result = super
        unless(@stacks.size > 1)
          result.delete('stack_name')
        end
        result
      end
    end
  end
end
