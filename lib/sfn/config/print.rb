require 'sfn'

module Sfn
  class Config
    # Print command configurationUpdate command configuration
    class Print < Validate
      attribute(
        :write_to_file, String,
        :description => 'Write compiled SparkleFormation template to path provided',
        :short_flag => 'w',
      )

      attribute(
        :sparkle_dump, [TrueClass, FalseClass],
        :description => 'Do not use provider customized dump behavior',
      )

      attribute(
        :yaml, [TrueClass, FalseClass],
        :description => 'Output template content in YAML format',
      )
    end
  end
end
