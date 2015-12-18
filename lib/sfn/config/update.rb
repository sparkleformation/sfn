require 'sfn'

module Sfn
  class Config
    # Update command configuration
    class Update < Validate

      attribute(
        :apply_stack, String,
        :multiple => true,
        :description => 'Apply outputs from stack to input parameters'
      )
      attribute(
        :parameter, Smash,
        :multiple => true,
        :description => '[DEPRECATED - use `parameters`] Pass template parameters directly (ParamName:ParamValue)',
        :coerce => lambda{|v, inst|
          result = inst.data[:parameter] || Array.new
          case v
          when String
            v.split(',').each do |item|
              result.push(Smash[*item.split(/[=:]/, 2)])
            end
          else
            result.push(v.to_smash)
          end
          {:bogo_multiple => result}
        }
      )
      attribute(
        :parameters, Smash,
        :description => 'Pass template parameters directly'
      )
      attribute(
        :plan, [TrueClass, FalseClass],
        :default => true,
        :description => 'Provide planning information prior to update'
      )
      attribute(
        :compile_parameters, Smash,
        :description => 'Pass template compile time parameters directly'
      )

    end
  end
end
