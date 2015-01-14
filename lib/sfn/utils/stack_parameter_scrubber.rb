require 'sfn'

module Sfn
  module Utils
    # Helper for scrubbing stack parameters
    class StackParameterScrubber

      class << self

        # Validate attributes within Parameter blocks
        ALLOWED_PARAMETER_ATTRIBUTES = %w(
          Type Default NoEcho AllowedValues AllowedPattern
          MaxLength MinLength MaxValue MinValue Description
          ConstraintDescription
        )

        # Clean the parameters of the template
        #
        # @param template [Hash]
        # @return [Hash] template
        def scrub!(template)
          parameters = template['Parameters']
          if(parameters)
            parameters.each do |name, options|
              options.delete_if do |attribute, value|
                !ALLOWED_PARAMETER_ATTRIBUTES.include?(attribute)
              end
            end
            template['Parameters'] = parameters
          end
          template
        end

      end
    end
  end
end
