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
        @stacks = []
        @stack = provider.connection.stacks.get(name)
        @stacks << stack
        discover_stacks(stack)
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
              while(stack.in_progress?)
                to_wait = config.fetch(:poll_wait_time, 10).to_f
                while(to_wait > 0)
                  sleep(0.1)
                  to_wait -= 0.1
                end
                stack.reload
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
        discover_stacks(stack)
        stack_events = @stacks.map do |stack|
          stack.events.all.map do |e|
            e.attributes.merge(:stack_name => stack.name).to_smash
          end
        end.flatten.compact.find_all{|e| e[:time] }
        stack_events.sort do |x,y|
          Time.parse(x[:time].to_s) <=> Time.parse(y[:time].to_s)
        end
      end

      # Discover stacks defined within the resources of given stack
      #
      # @param stack [Miasma::Models::Orchestration::Stack]
      def discover_stacks(stack)
        stack.resources.reload.all.each do |resource|
          if(resource.type == 'AWS::CloudFormation::Stack')
            nested_stack = provider.connection.stacks.get(resource.id)
            if(nested_stack)
              @stacks.push(nested_stack).uniq!
              discover_stacks(nested_stack)
            end
          end
        end
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
