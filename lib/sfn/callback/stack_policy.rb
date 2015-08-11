require 'sfn'

module Sfn
  class Callback
    class StackPolicy < Callback

      # @return [Smash] cached policies
      attr_reader :policies

      # Overload to init policy cache
      #
      # @return [self]
      def initialize(*args)
        super
        @policies = Smash.new
      end

      # Submit all cached policies
      #
      # @param args [Hash]
      def submit_policy(args)
        ui.info 'Submitting stack policy documents'
        stack = args[:api_stack]
        ([stack] + stack.nested_stacks).compact.each do |p_stack|
          ui.run_action "Applying stack policy to #{ui.color(p_stack.name, :yellow)}" do
            save_stack_policy(p_stack)
          end
        end
        ui.info 'Stack policy documents successfully submitted!'
      end
      alias_method :after_create, :submit_policy
      alias_method :after_update, :submit_policy

      # Update all policies to allow resource destruction
      def before_destroy(args)
        ui.warn "Policy modification for deletion not currently enabled!"
      end

      # Remove all policies
      def after_destroy(args)
        ui.warn "Policy removal not currently enabled!"
      end

      # Generate stack policy for stack and cache for the after hook
      # to handle
      #
      # @param info [Hash]
      def stack(info)
        if(info[:sparkle_stack])
          @policies.set(info[:stack_name],
            info[:sparkle_stack].generate_policy
          )
        end
      end

      # Save the cached policy for the given stack
      #
      # @param p_stack [Miasma::Models::Orchestration::Stack]
      # @return [NilClass]
      def save_stack_policy(p_stack)
        result = p_stack.api.request(
          :path => '/',
          :method => :post,
          :form => Smash.new(
            'Action' => 'SetStackPolicy',
            'StackPolicyBody' => @policies[p_stack.name]
          )
        )
      end

    end
  end
end
