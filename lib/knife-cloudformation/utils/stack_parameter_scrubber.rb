require 'knife-cloudformation'

class KnifeCloudformation
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
        # @param
        def scrub!(template)
          template.fetch('Parameters', {}).each do |name, options|
            options.delete_if do |attribute, value|
              !ALLOWED_PARAMETER_ATTRIBUTES.include?(attribute)
            end
          end
        end

      end
    end
  end
end
