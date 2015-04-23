require 'sfn'

module Sfn
  class Config
    # Update command configuration
    class Update < Validate

      attribute(
        :print_only, [TrueClass, FalseClass],
        :description => 'Print the resulting stack template'
      )
      attribute(
        :apply_stack, String,
        :multiple => true,
        :description => 'Apply outputs from stack to input parameters'
      )
      attribute(
        :parameter, String,
        :multiple => true,
        :description => 'Pass template parameters directly (ParamName:ParamValue)'
      )

    end
  end
end
