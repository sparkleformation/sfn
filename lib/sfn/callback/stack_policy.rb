require 'sfn'

module Sfn
  class Callback
    class StackPolicy < Callback

      # Policy to apply prior to stack deletion
      DEFENSELESS_POLICY = {
        'Statement' => [{
            'Effect' => 'Allow',
            'Action' => 'Update:*',
            'Resource' => '*',
            'Principal' => '*'
          }]
      }

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
          run_action "Applying stack policy to #{ui.color(p_stack.name, :yellow)}" do
            save_stack_policy(p_stack)
          end
        end
        ui.info 'Stack policy documents successfully submitted!'
      end
      alias_method :after_create, :submit_policy
      alias_method :after_update, :submit_policy

      # Disable all existing policies prior to update
      #
      # @param args [Hash]
      def before_update(args)
        if(config.get(:stack_policy, :update).to_s == 'defenseless')
          ui.warn 'Disabling all stack policies for update.'
          stack = args[:api_stack]
          ([stack] + stack.nested_stacks).compact.each do |p_stack|
            @policies[p_stack.name] = DEFENSELESS_POLICY
            run_action "Disabling stack policy for #{ui.color(p_stack.name, :yellow)}" do
              save_stack_policy(p_stack)
            end
          end
        end
      end

      # Generate stack policy for stack and cache for the after hook
      # to handle
      #
      # @param info [Hash]
      def template(info)
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
            'StackName' => p_stack.id,
            'StackPolicyBody' => MultiJson.dump(
              @policies.fetch(p_stack.id,
                @policies.fetch(p_stack.data[:logical_id],
                  @policies[p_stack.name]
                )
              )
            )
          )
        )
      end

    end
  end
end
