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

      attribute(
        :tags, [TrueClass, FalseClass],
        :description => 'Display stack tags'
      )

    end
  end
end
