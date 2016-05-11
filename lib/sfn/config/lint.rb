require 'sfn'

module Sfn
  class Config
    # Lint command configuration
    class Lint < Validate

      attribute(
        :lint_directory, String,
        :description => 'Directory containing lint rule sets',
        :multiple => true
      )

    end
  end
end
