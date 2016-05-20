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
      attribute(
        :disabled_rule_set, String,
        :description => 'Disable rule set from being applied',
        :multiple => true
      )
      attribute(
        :enabled_rule_set, String,
        :description => 'Only apply this rule set',
        :multiple => true
      )
      attribute(
        :local_rule_sets_only, [TrueClass, FalseClass],
        :description => 'Only apply rule sets provided by lint directory',
        :default => false
      )
    end
  end
end
