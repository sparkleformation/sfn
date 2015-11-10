require 'sfn'

module Sfn
  class Config
    # Validate command configuration
    class Validate < Config

      attribute(
        :processing, [TrueClass, FalseClass],
        :description => 'Call the unicorns and explode the glitter bombs',
        :default => true
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
        :description => 'Chunk length for serialization',
        :coerce => lambda{|v| v.to_i}
      )
      attribute(
        :apply_nesting, [String, Symbol],
        :default => 'deep',
        :description => 'Apply stack nesting'
      )
      attribute(
        :nesting_bucket, String,
        :description => 'Bucket to use for storing nested stack templates'
      )
      attribute(
        :print_only, [TrueClass, FalseClass],
        :description => 'Print the resulting stack template'
      )
      attribute(
        :sparkle_pack, String,
        :multiple => true,
        :description => 'Load SparklePack gem',
        :coerce => lambda{|s| require s; s}
      )

    end
  end
end
