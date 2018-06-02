require "sfn"
require "jmespath"

module Sfn
  module Lint
    autoload :Definition, "sfn/lint/definition"
    autoload :Rule, "sfn/lint/rule"
    autoload :RuleSet, "sfn/lint/rule_set"
  end
end
