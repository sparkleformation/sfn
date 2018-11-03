require "sfn"

module Sfn
  class Config
    # Plan command configuration
    class Plan < Create
      # Remove the plan option. Command specific options will
      # cause a conflict if same option name as command is used.
      # Also, since this is a plan command, we are always running
      # a plan, because that's the command.
      attributes.delete(:plan)
      # Default diffs to be enabled
      attributes.set(:diffs, :default, true)

      attribute(
        :plan_name, String,
        :description => "Custom plan name or ID (not applicable to all providers)",
      )

      attribute(
        :load_existing, TRISTATE_BOOLEAN,
        :description => "Load existing plan if exists",
        :default => nil
      )

      attribute(
        :auto_destroy_stack, TRISTATE_BOOLEAN,
        :description => "Automatically destroy empty stack",
        :default => nil
      )

      attribute(
        :auto_destroy_plan, TRISTATE_BOOLEAN,
        :description => "Automatically destroy generated plan",
        :default => nil
      )

      attribute(
        :list, BOOLEAN,
        :description => "List all available plans for stack",
        :default => false,
        :short_flag => "l",
      )
    end
  end
end
