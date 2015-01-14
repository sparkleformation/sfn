require 'sfn'

module Sfn
  module Utils

    # Helper utility for validating stack parameters
    class StackParameterValidator
      class << self

        include Bogo::AnimalString

        # Validate a parameters
        #
        # @param value [Object] value for parameter
        # @param parameter_definition [Hash]
        # @option parameter_definition [Array<String>] 'AllowedValues'
        # @option parameter_definition [String] 'AllowedPattern'
        # @option parameter_definition [String, Integer] 'MaxLength'
        # @option parameter_definition [String, Integer] 'MinLength'
        # @option parameter_definition [String, Integer] 'MaxValue'
        # @option parameter_definition [String, Integer] 'MinValue'
        # @return [TrueClass, Array<String>] true if valid. array of string errors if invalid
        def validate(value, parameter_definition)
          return [[:blank, 'Value cannot be blank']] if value.to_s.strip.empty?
          result = %w(AllowedValues AllowedPattern MaxLength MinLength MaxValue MinValue).map do |key|
            if(parameter_definition[key])
              res = self.send(snake(key), value, parameter_definition)
              res == true ? true : [snake(key), res]
            else
              true
            end
          end
          result.delete_if{|x| x == true}
          result.empty? ? true : result
        end

        # Parameter is within allowed values
        #
        # @param value [String]
        # @param pdef [Hash] parameter definition
        # @option pdef [Array<String>] 'AllowedValues'
        # @return [TrueClass, String]
        def allowed_values(value, pdef)
          if(pdef['AllowedValues'].include?(value))
            true
          else
            "Not an allowed value: #{pdef['AllowedValues'].join(', ')}"
          end
        end

        # Parameter matches allowed pattern
        #
        # @param value [String]
        # @param pdef [Hash] parameter definition
        # @option pdef [String] 'AllowedPattern'
        # @return [TrueClass, String]
        def allowed_pattern(value, pdef)
          if(value.match(/#{pdef['AllowedPattern']}/))
            true
          else
            "Not a valid pattern. Must match: #{pdef['AllowedPattern']}"
          end
        end

        # Parameter length is less than or equal to max length
        #
        # @param value [String, Integer]
        # @param pdef [Hash] parameter definition
        # @option pdef [String] 'MaxLength'
        # @return [TrueClass, String]
        def max_length(value, pdef)
          if(value.length <= pdef['MaxLength'].to_i)
            true
          else
            "Value must not exceed #{pdef['MaxLength']} characters"
          end
        end

        # Parameter length is greater than or equal to min length
        #
        # @param value [String]
        # @param pdef [Hash] parameter definition
        # @option pdef [String] 'MinLength'
        # @return [TrueClass, String]
        def min_length(value, pdef)
          if(value.length >= pdef['MinLength'].to_i)
            true
          else
            "Value must be at least #{pdef['MinLength']} characters"
          end
        end

        # Parameter value is less than or equal to max value
        #
        # @param value [String]
        # @param pdef [Hash] parameter definition
        # @option pdef [String] 'MaxValue'
        # @return [TrueClass, String]
        def max_value(value, pdef)
          if(value.to_i <= pdef['MaxValue'].to_i)
            true
          else
            "Value must not be greater than #{pdef['MaxValue']}"
          end
        end

        # Parameter value is greater than or equal to min value
        #
        # @param value [String]
        # @param pdef [Hash] parameter definition
        # @option pdef [String] 'MinValue'
        # @return [TrueClass, String]
        def min_value(value, pdef)
          if(value.to_i >= pdef['MinValue'].to_i)
            true
          else
            "Value must not be less than #{pdef['MinValue']}"
          end
        end

      end
    end
  end
end
