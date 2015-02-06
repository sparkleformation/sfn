require 'sfn'

module Sfn
  class Config
    class Describe < Bogo::Config

      attribute(
        :resources, [TrueClass, FalseClass],
        :description => 'Display stack resource list'
      )

      attribute(
        :outputs, [TrueClass, FalseClass],
        :description => 'Display stack outputs'
      )

    end
  end
end
