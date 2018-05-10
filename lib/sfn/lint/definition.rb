require "sfn"

module Sfn
  module Lint
    # Lint defition
    class Definition

      # @return [String] search expression used for matching
      attr_reader :search_expression
      # @return [Proc-ish] must respond to #call
      attr_reader :evaluator
      # @return [Symbol] target provider
      attr_reader :provider

      # Create a new definition
      #
      # @param expr [String] search expression used for matching
      # @param provider [String, Symbol] target provider
      # @param evaluator [Proc] logic used to handle match
      # @return [self]
      def initialize(expr, provider = :aws, evaluator = nil, &block)
        if evaluator && block
          raise ArgumentError.new "Only evaluator or block can be provided, not both."
        end
        @provider = Bogo::Utility.snake(provider).to_sym
        @search_expression = expr
        @evaluator = evaluator || block
      end

      # Apply definition to template
      #
      # @param template [Hash] template being processed
      # @return [TrueClass, Array<String>] true if passed. List of string results that failed
      def apply(template)
        result = JMESPath.search(search_expression, template)
        run(result, template)
      end

      protected

      # Check result of search expression
      #
      # @param result [Object] result(s) of search expression
      # @param template [Hash] full template
      # @return [TrueClass, Array<String>] true if passed. List of string results that failed
      # @note override this method when subclassing
      def run(result, template)
        unless evaluator
          raise NotImplementedError.new "No evaluator has been defined for this definition!"
        end
        evaluator.call(result, template)
      end
    end
  end
end
