require 'sfn'

module Sfn
  class Config
    class Describe < Config

      attribute(
        :resources, [TrueClass, FalseClass],
        :description => 'Display stack resource list',
        :short_flag => 'r'
      )

      attribute(
        :outputs, [TrueClass, FalseClass],
        :description => 'Display stack outputs',
        :short_flag => 'o'
      )

      attribute(
        :tags, [TrueClass, FalseClass],
        :description => 'Display stack tags',
        :short_flag => 't'
      )

    end
  end
end
