require "sfn"

module Sfn
  # Utility classes and modules
  module Utils
    autoload :Output, "sfn/utils/output"
    autoload :StackParameterValidator, "sfn/utils/stack_parameter_validator"
    autoload :StackParameterScrubber, "sfn/utils/stack_parameter_scrubber"
    autoload :StackExporter, "sfn/utils/stack_exporter"
    autoload :Debug, "sfn/utils/debug"
    autoload :JSON, "sfn/utils/json"
    autoload :Ssher, "sfn/utils/ssher"
    autoload :ObjectStorage, "sfn/utils/object_storage"
    autoload :PathSelector, "sfn/utils/path_selector"

    # Provide methods directly from module for previous version compatibility
    extend JSON
    extend ObjectStorage
    extend Bogo::AnimalStrings
  end
end
