require 'sfn'

module Sfn
  class Config
    # Update command configuration
    class Update < Validate

      attribute(
        :apply_stack, String,
        :multiple => true,
        :description => 'Apply outputs from stack to input parameters',
        :short_flag => 'A'
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
        },
        :short_flag => 'R'
      )
      attribute(
        :parameters, Smash,
        :description => 'Pass template parameters directly',
        :short_flag => 'm'
      )
      attribute(
        :plan, [TrueClass, FalseClass],
        :default => true,
        :description => 'Provide planning information prior to update',
        :short_flag => 'l'
      )
      attribute(
        :compile_parameters, Smash,
        :description => 'Pass template compile time parameters directly',
        :short_flag => 'o'
      )

    end
  end
end
