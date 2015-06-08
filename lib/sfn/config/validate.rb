require 'sfn'

module Sfn
  class Config
    # Validate command configuration
    class Validate < Config

      attribute(
        :processing, [TrueClass, FalseClass],
        :description => 'Call the unicorns and explode the glitter bombs'
      )
      attribute(
        :file, String,
        :description => 'Path to template file',
        :default => nil
      )
      attribute(
        :file_path_prompt, [TrueClass, FalseClass],
        :default => true,
        :description => 'Enable interactive prompt for template path discovery'
      )
      attribute(
        :base_directory, String,
        :description => 'Path to root of of templates directory'
      )
      attribute(
        :no_base_directory, [TrueClass, FalseClass],
        :description => 'Unset any value used for the template root directory path'
      )
      attribute(
        :translate, String,
        :description => 'Translate generated template to given prodiver'
      )
      attribute(
        :translate_chunk, Integer,
        :description => 'Chunk length for serialization'
      )
      attribute(
        :apply_nesting, [TrueClass, FalseClass],
        :default => true,
        :description => 'Apply stack nesting'
      )
      attribute(
        :nesting_bucket, String,
        :description => 'Bucket to use for storing nested stack templates'
      )

    end
  end
end
