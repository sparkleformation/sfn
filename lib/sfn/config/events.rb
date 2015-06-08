require 'sfn'

module Sfn
  class Config
    # Events command configuration
    class Events < Config

      attribute(
        :attribute, String,
        :multiple => true,
        :description => 'Event attribute to display'
      )
      attribute(
        :poll_delay, Integer,
        :default => 20,
        :description => 'Seconds to pause between each event poll'
      )
      attribute(
        :all_attributes, [TrueClass, FalseClass],
        :description => 'Display all event attributes'
      )

    end
  end
end
