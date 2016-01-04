require 'sfn'

module Sfn
  class Config
    # Create command configuration
    class Create < Update

      attribute(
        :timeout, Integer,
        :coerce => proc{|v| v.to_i},
        :description => 'Seconds to wait for stack to complete',
        :short_flag => 'M'
      )
      attribute(
        :rollback, [TrueClass, FalseClass],
        :description => 'Rollback stack on failure',
        :short_flag => 'O'
      )
      attribute(
        :capabilities, String,
        :multiple => true,
        :description => 'Capabilities to allow the stack',
        :short_flag => 'B'
      )
      attribute(
        :options, Smash,
        :description => 'Extra options to apply to the API call',
        :short_flag => 'S'
      )
      attribute(
        :notification_topics, String,
        :multiple => true,
        :description => 'Notification endpoints for stack events',
        :short_flag => 'z'
      )

    end
  end
end
