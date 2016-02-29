require 'sfn'

module Sfn
  class Config
    # Print command configurationUpdate command configuration
    class Print < Validate

      attribute(
        :write_to_file, String,
        :description => 'Write compiled SparkleFormation template to path provided',
        :short_flag => 'w'
      )

    end
  end
end
