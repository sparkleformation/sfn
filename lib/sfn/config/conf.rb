require 'sfn'

module Sfn
  class Config
    # Config command configuration (subclass create to get all the configs)
    class Conf < Create
      attribute(
        :generate, [TrueClass, FalseClass],
        :description => 'Generate a basic configuration file',
        :short_flag => 'g',
      )
    end
  end
end
