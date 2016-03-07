require 'sfn'

module Sfn
  class Config
    # Events command configuration
    class Events < Config

      attribute(
        :attribute, String,
        :multiple => true,
        :description => 'Event attribute to display',
        :short_flag => 'a'
      )
      attribute(
        :poll_delay, Integer,
        :default => 20,
        :description => 'Seconds to pause between each event poll',
        :coerce => lambda{|v| v.to_i},
        :short_flag => 'P'
      )
      attribute(
        :all_attributes, [TrueClass, FalseClass],
        :description => 'Display all event attributes',
        :short_flag => 'A'
      )
      attribute(
        :all_events,  [TrueClass, FalseClass],
        :description => 'Display all available events',
        :short_flag => 'L'
      )

    end
  end
end
