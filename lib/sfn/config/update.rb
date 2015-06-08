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
        :parameter, Smash,
        :multiple => true,
        :description => 'Pass template parameters directly (ParamName:ParamValue)',
        :coerce => lambda{|v|
          v.is_a?(String) ? Smash[*v.split(/[=:]/, 2)] : v
        }
      )

    end
  end
end
