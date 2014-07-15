require 'knife-cloudformation'

module KnifeCloudformation
  # Utility classes and modules
  module Utils

    autoload :Output, 'knife-cloudformation/utils/output'
    autoload :StackParameterValidator, 'knife-cloudformation/utils/stack_parameter_validator'
    autoload :StackParameterScrubber, 'knife-cloudformation/utils/stack_parameter_scrubber'
    autoload :StackExporter, 'knife-cloudformation/utils/stack_exporter'
    autoload :Debug, 'knife-cloudformation/utils/debug'
    autoload :JSON, 'knife-cloudformation/utils/json'
    autoload :AnimalStrings, 'knife-cloudformation/utils/animal_strings'
    autoload :Ssher, 'knife-cloudformation/utils/ssher'
    autoload :ObjectStorage, 'knife-cloudformation/utils/object_storage'

    # Provide methods directly from module for previous version compatibility
    extend JSON
    extend AnimalStrings
    extend ObjectStorage

  end
end
