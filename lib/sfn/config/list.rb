require "sfn"

module Sfn
  class Config
    # List command configuration
    class List < Sfn::Config
      attribute(
        :attribute, String,
        :multiple => true,
        :description => "Attribute of stack to print",
        :short_flag => "a",
      )
      attribute(
        :all_attributes, [TrueClass, FalseClass],
        :description => "Print all available attributes",
        :short_flag => "A",
      )
      attribute(
        :status, String,
        :multiple => true,
        :description => 'Match stacks with given status. Use "none" to disable.',
        :short_flag => "s",
      )
    end
  end
end
