require 'sfn'

module Sfn
  class Config
    # Validate command configuration
    class Validate < Config

      attribute(
        :processing, [TrueClass, FalseClass],
        :description => 'Call the unicorns and explode the glitter bombs',
        :default => true,
        :short_flag => 'P'
      )
      attribute(
        :file, String,
        :description => 'Path to template file',
        :default => nil,
        :short_flag => 'f'
      )
      attribute(
        :file_path_prompt, [TrueClass, FalseClass],
        :default => true,
        :description => 'Enable interactive prompt for template path discovery',
        :short_flag => 'F'
      )
      attribute(
        :base_directory, String,
        :description => 'Path to root of of templates directory',
        :short_flag => 'b'
      )
      attribute(
        :no_base_directory, [TrueClass, FalseClass],
        :description => 'Unset any value used for the template root directory path',
        :short_flag => 'n'
      )
      attribute(
        :translate, String,
        :description => 'Translate generated template to given provider',
        :short_flag => 't'
      )
      attribute(
        :translate_chunk, Integer,
        :description => 'Chunk length for serialization',
        :coerce => lambda{|v| v.to_i},
        :short_flag => 'T'
      )
      attribute(
        :apply_nesting, [String, Symbol],
        :default => 'deep',
        :description => 'Apply stack nesting',
        :short_flag => 'a'
      )
      attribute(
        :nesting_bucket, String,
        :description => 'Bucket to use for storing nested stack templates',
        :short_flag => 'N'
      )
      attribute(
        :nesting_prefix, String,
        :description => 'File name prefix for storing template in bucket',
        :short_flag => 'Y'
      )
      attribute(
        :print_only, [TrueClass, FalseClass],
        :description => 'Print the resulting stack template',
        :short_flag => 'r'
      )
      attribute(
        :sparkle_pack, String,
        :multiple => true,
        :description => 'Load SparklePack gem',
        :coerce => lambda{|s| s.to_s},
        :short_flag => 's'
      )
      attribute(
        :compile_parameters, Smash,
        :description => 'Pass template compile time parameters directly',
        :short_flag => 'o',
        :coerce => lambda{|v|
          case v
          when String
            result = Smash.new
            v.split(',').each do |item_pair|
              key, value = item_pair.split(/[=:]/, 2)
              key = key.split('__')
              key = [key.pop, key.map{|x| Bogo::Utility.camel(x)}.join('__')].reverse
              result.set(*key, value)
            end
            result
          when Hash
            v.to_smash
          else
            v
          end
        }
      )

    end
  end
end
