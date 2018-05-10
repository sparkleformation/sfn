require "sfn"

module Sfn
  class Command
    # Cloudformation describe command
    class Describe < Command
      include Sfn::CommandModule::Base

      # information available
      unless defined?(AVAILABLE_DISPLAYS)
        AVAILABLE_DISPLAYS = [:resources, :outputs, :tags]
      end

      # Run the stack describe action
      def execute!
        name_required!
        stack_name = name_args.last
        root_stack = api_action! do
          provider.stack(stack_name)
        end
        if root_stack
          ([root_stack] + root_stack.nested_stacks).compact.each do |stack|
            ui.info "Stack description of #{ui.color(stack.name, :bold)}:"
            display = [].tap do |to_display|
              AVAILABLE_DISPLAYS.each do |display_option|
                if config[display_option]
                  to_display << display_option
                end
              end
            end
            display = AVAILABLE_DISPLAYS.dup if display.empty?
            display.each do |display_method|
              self.send(display_method, stack)
            end
            ui.puts
          end
        else
          ui.fatal "Failed to find requested stack: #{ui.color(stack_name, :bold, :red)}"
          raise "Requested stack not found: #{stack_name}"
        end
      end

      # Display resources
      #
      # @param stack [Miasma::Models::Orchestration::Stack]
      def resources(stack)
        stack_resources = stack.resources.all.sort do |x, y|
          y.updated <=> x.updated
        end.map do |resource|
          Smash.new(resource.attributes)
        end
        ui.table(self) do
          table(:border => false) do
            row(:header => true) do
              allowed_attributes.each do |attr|
                column as_title(attr), :width => stack_resources.map { |r| r[attr].to_s.length }.push(as_title(attr).length).max + 2
              end
            end
            stack_resources.each do |resource|
              row do
                allowed_attributes.each do |attr|
                  column resource[attr]
                end
              end
            end
          end
        end.display
      end

      # Display outputs
      #
      # @param stack [Miasma::Models::Orchestration::Stack]
      def outputs(stack)
        ui.info "Outputs for stack: #{ui.color(stack.name, :bold)}"
        unless stack.outputs.nil? || stack.outputs.empty?
          stack.outputs.each do |output|
            key, value = output.key, output.value
            key = snake(key).to_s.split("_").map(&:capitalize).join(" ")
            ui.info ["  ", ui.color("#{key}:", :bold), value].join(" ")
          end
        else
          ui.info "  #{ui.color("No outputs found")}"
        end
      end

      # Display tags
      #
      # @param stack [Miasma::Models::Orchestration::Stack]
      def tags(stack)
        ui.info "Tags for stack: #{ui.color(stack.name, :bold)}"
        if stack.tags && !stack.tags.empty?
          stack.tags.each do |key, value|
            ui.info ["  ", ui.color("#{key}:", :bold), value].join(" ")
          end
        else
          ui.info "  #{ui.color("No tags found")}"
        end
      end

      # @return [Array<String>] default attributes
      def default_attributes
        %w(updated logical_id type status status_reason)
      end
    end
  end
end
