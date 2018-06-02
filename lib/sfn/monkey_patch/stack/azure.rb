require "sfn"

module Sfn
  module MonkeyPatch
    module Stack
      # Azure specific monkey patch implementations
      module Azure

        # @return [Hash] restructured azure template
        # @note Will return #template if name collision encountered within resources
        def sparkleish_template_azure
          new_template = template.to_smash
          resources = new_template.delete(:resources)
          resources.each do |resource|
            new_template.set(:resources, resource.delete(:name), resource)
          end
          resources.size == new_template[:resources].size ? new_template : template
        end
      end
    end
  end
end
