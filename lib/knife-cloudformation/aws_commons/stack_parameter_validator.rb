require 'knife-cloudformation/aws_commons/stack'

module KnifeCloudformation
  class AwsCommons

    class Stack

      class ParameterValidator
        class << self

          include KnifeCloudformation::Utils::AnimalStrings

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

          def allowed_values(value, pdef)
            if(pdef['AllowedValues'].include?(value))
              true
            else
              "Not an allowed value: #{pdef['AllowedValues'].join(', ')}"
            end
          end

          def allowed_pattern(value, pdef)
            if(value.match(/#{pdef['AllowedPattern']}/))
              true
            else
              "Not a valid pattern. Must match: #{pdef['AllowedPattern']}"
            end
          end

          def max_length(value, pdef)
            if(value.length <= pdef['MaxLength'].to_i)
              true
            else
              "Value must not exceed #{pdef['MaxLength']} characters"
            end
          end

          def min_length(value, pdef)
            if(value.length >= pdef['MinLength'].to_i)
              true
            else
              "Value must be at least #{pdef['MinLength']} characters"
            end
          end

          def max_value(value, pdef)
            if(value.to_i <= pdef['MaxValue'].to_i)
              true
            else
              "Value must not be greater than #{pdef['MaxValue']}"
            end
          end

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
end
