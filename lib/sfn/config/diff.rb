require 'sfn'

module Sfn
  class Config
    # Diff new template with existing stack template
    class Diff < Update
      attribute(
        :raw_diff, [TrueClass, FalseClass],
        :default => false,
        :description => 'Display raw diff information',
        :short_flag => 'w',
      )
    end
  end
end
