require 'sfn'

module Sfn
  class Config
    # Create command configuration
    class Create < Update

      attribute(
        :timeout, Integer,
        :coerce => proc{|v| v.to_i},
        :description => 'Seconds to wait for stack to complete'
      )
      attribute(
        :rollback, [TrueClass, FalseClass],
        :description => 'Rollback stack on failure'
      )
      attribute(
        :capabilities, String,
        :multiple => true,
        :description => 'Capabilities to allow the stack'
      )
      attribute(
        :options, String,
        :multiple => true,
        :description => 'Extra options to apply to the API call'
      )
      attribute(
        :notifications, String,
        :multiple => true,
        :description => 'Notification endpoints for stack events'
      )

    end
  end
end
