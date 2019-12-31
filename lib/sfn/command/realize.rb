require "sfn"

module Sfn
  class Command
    # Realize command
    class Realize < Command
      include Sfn::CommandModule::Base
      include Sfn::CommandModule::Planning

      # Run the stack realize command
      def execute!
        name_required!
        name = name_args.first

        stack_info = "#{ui.color("Name:", :bold)} #{name}"
        begin
          stack = provider.stacks.get(name)
        rescue Miasma::Error::ApiError::RequestError => error
          ui.error error.message unless error.response.code == 404
          raise Error::StackNotFound,
            "Failed to locate stack: #{name}"
        end

        if config[:plan_name]
          ui.debug "Setting custom plan name - #{config[:plan_name]}"
          # ensure custom attribute is dirty so we can modify
          stack.custom = stack.custom.dup
          stack.custom[:plan_name] = config[:plan_name]
        end

        ui.info " -> Loading plan information..."

        plan = stack.plan
        if plan.nil?
          raise Error::StackPlanNotFound,
            "Failed to locate plan for stack `#{name}`"
        end

        display_plan_information(plan)

        return if config[:plan_only]

        if config[:merge_api_options]
          config.fetch(:options, Smash.new).each_pair do |key, value|
            if stack.respond_to?("#{key}=")
              stack.send("#{key}=", value)
            end
          end
        end

        begin
          api_action!(:api_stack => stack) do
            stack.plan_execute
            if config[:poll]
              poll_stack(stack.name)
              if [:update_complete, :create_complete].
                include?(stack.reload.state)
                ui.info "Stack plan apply complete: " \
                        "#{ui.color("SUCCESS", :green)}"
                namespace.const_get(:Describe).
                  new({:outputs => true}, [name]).execute!
              else
                ui.fatal "Update of stack #{ui.color(name, :bold)}: " \
                         "#{ui.color("FAILED", :red, :bold)}"
                raise Error::StackStateIncomplete
              end
            else
              ui.warn "Stack state polling has been disabled."
              ui.info "Stack plan apply initialized for " \
                      "#{ui.color(name, :green)}"
            end
          end
        rescue Miasma::Error::ApiError::RequestError => e
          if e.message.downcase.include?("no updates")
            ui.warn "No changes detected for stack (#{stack.name})"
          else
            raise
          end
        end
      end
    end
  end
end
