require "sfn"

module Sfn
  module Lint
    # Composition of definitions
    class Rule

      # @return [Symbol] name of rule
      attr_reader :name
      # @return [Array<Definition>] definitions composing rule
      attr_reader :definitions
      # @return [String] message describing failure
      attr_reader :fail_message
      # @return [Symbol] target provider
      attr_reader :provider

      # Create a new rule
      #
      # @param name [String, Symbol] name of rule
      # @param definitions [Array<Definition>] definitions composing rule
      # @param fail_message [String] message to describe failure
      # @param provider [String, Symbol] target provider
      # @return [self]
      def initialize(name, definitions, fail_message, provider = :aws)
        @name = name.to_sym
        @definitions = definitions.dup.uniq.freeze
        @fail_message = fail_message
        @provider = Bogo::Utility.snake(provider).to_sym
        validate_definitions!
      end

      # Generate the failure message for this rule with given failure
      # result set.
      def generate_fail_message(results)
        msg = fail_message.dup
        unless results.empty?
          failed_items = results.map do |item|
            f_item = item[:failures]
            next if f_item.nil? || f_item == true || f_item == false
            f_item
          end.flatten.compact.map(&:to_s)
          unless failed_items.empty?
            msg = "#{msg} (failures: `#{failed_items.join("`, `")}`)"
          end
        end
        msg
      end

      # Apply all definitions to template
      #
      # @param template [Hash]
      # @return [TrueClass, Array<Smash[:definition, :failures]>] true if passed. Definition failures if failed.
      def apply(template)
        results = definitions.map do |definition|
          result = definition.apply(template)
          result == true ? result : Smash.new(:definition => definition, :failures => result)
        end
        if results.all? { |item| item == true }
          true
        else
          results.delete_if { |item| item == true }
          results
        end
      end

      # Check if template passes this rule
      #
      # @param template [Hash]
      # @return [TrueClass, FalseClass]
      def pass?(template)
        apply(template) == true
      end

      # Check if template fails this rule
      #
      # @param template [Hash]
      # @return [TrueClass, FalseClass]
      def fail?(template)
        !pass?(template)
      end

      # Add a new definition to the collection
      #
      # @param definition [Definition] new definition to add
      # @return [self]
      def add_definition(definition)
        new_defs = definitions.dup
        new_defs << definition
        @definitions = new_defs.uniq.freeze
        validate_definitions!
        self
      end

      # Remove a definition from the collection
      #
      # @param definition [Definition] definition to remove
      # @return [self]
      def remove_definition(definition)
        new_defs = definitions.dup
        new_defs.delete(definition)
        @definitions = new_defs.uniq.freeze
        self
      end

      # Check that provided definitions provider match rule defined provider
      def validate_definitions!
        non_match = definitions.find_all do |definition|
          definition.provider != provider
        end
        unless non_match.empty?
          raise ArgumentError.new "Rule defines `#{provider}` as provider but includes definitions for " \
                                  "non matching providers. (#{non_match.map(&:provider).map(&:to_s).uniq.sort.join(", ")})"
        end
      end
    end
  end
end
