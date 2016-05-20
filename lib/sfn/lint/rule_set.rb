require 'sfn'

module Sfn
  module Lint
    # Named collection of rules
    class RuleSet

      # Helper class for ruleset generation
      class Creator

        attr_reader :items, :provider

        def initialize(provider)
          @provider = provider
          @items = []
        end

        class RuleSet < Creator

          def rule(name, &block)
            r = Rule.new(provider)
            r.instance_exec(&block)
            items << Sfn::Lint::Rule.new(name, r.items, r.fail_message, provider)
          end

        end

        class Rule < Creator

          def definition(expr, evaluator=nil, &block)
            items << Sfn::Lint::Definition.new(expr, provider, evaluator, &block)
          end

          def fail_message(val=nil)
            unless(val.nil?)
              @fail_message = val
            end
            @fail_message
          end

        end

      end

      class << self

        @@_rule_set_registry = Smash.new

        # RuleSet generator helper for quickly building simple rule sets
        #
        # @param name [String] name of rule set
        # @param provider [String, Symbol] target provider
        # @yieldblock rule set content
        def build(name, provider=:aws, &block)
          provider = Bogo::Utility.snake(provider).to_sym
          rs = Creator::RuleSet.new(provider)
          rs.instance_exec(&block)
          self.new(name, provider, rs.items)
        end

        # Register a rule set
        #
        # @param rule_set [RuleSet]
        # @return [TrueClass]
        def register(rule_set)
          @@_rule_set_registry.set(rule_set.provider, rule_set.name, rule_set)
          true
        end

        # Get registered rule set
        #
        # @param name [String] name of rule set
        # @param provider [String] target provider
        # @return [RuleSet, NilClass]
        def get(name, provider=:aws)
          provider = Bogo::Utility.snake(provider)
          @@_rule_set_registry.get(provider, name)
        end

        # Get all rule sets for specified provider
        #
        # @param provider [String] target provider
        # @return [Array<RuleSet>]
        def get_all(provider=:aws)
          @@_rule_set_registry.fetch(provider, {}).values
        end

      end

      include Bogo::Memoization

      # @return [Symbol] name
      attr_reader :name
      # @return [Symbol] target provider
      attr_reader :provider
      # @return [Array<Rule>] rules of set
      attr_reader :rules

      # Create new rule set
      #
      # @param name [String, Symbol] name of rule set
      # @param provider [String, Symbol] name of target provider
      # @param rules [Array<Rule>] list of rules defining this set
      # @return [self]
      def initialize(name, provider=:aws, rules=[])
        @name = name.to_sym
        @provider = Bogo::Utility.snake(provider).to_sym
        @rules = rules.dup.uniq.freeze
        validate_rules!
      end

      # Add a new rule to the collection
      #
      # @param rule [Rule] new rule to add
      # @return [self]
      def add_rule(rule)
        new_rules = rules.dup
        new_rules << rule
        @rules = new_rules.uniq.freeze
        validate_rules!
        self
      end

      # Remove a rule from the collection
      #
      # @param rule [Rule] rule to remove
      # @return [self]
      def remove_rule(rule)
        new_rules = rules.dup
        new_rules.delete(rule)
        @rules = new_rules.uniq.freeze
        self
      end

      # Apply rule set to template.
      #
      # @param template [Hash]
      # @return [TrueClass, Array<String>] true on success, list failure messages on failure
      def apply(template)
        failures = collect_failures(template)
        if(failures.empty?)
          true
        else
          failures.map do |failure|
            failure[:rule].generate_fail_message(failure[:result])
          end
        end
      end

      # Process template through rules defined in this set and
      # store failure information
      #
      # @param template [Hash]
      # @return [Array<Rule>] list of failures
      def collect_failures(template)
        results = rules.map do |rule|
          result = rule.apply(template)
          result == true ? true : Smash.new(:rule => rule, :result => result)
        end
        results.delete_if{|i| i == true}
        results
      end

      # Check that provided rules provider match rule set defined provider
      def validate_rules!
        non_match = rules.find_all do |rule|
          rule.provider != provider
        end
        unless(non_match.empty?)
          raise ArgumentError.new "Rule set defines `#{provider}` as provider but includes rules for " \
            "non matching providers. (#{non_match.map(&:provider).map(&:to_s).uniq.sort.join(', ')})"
        end
      end

    end
  end
end
