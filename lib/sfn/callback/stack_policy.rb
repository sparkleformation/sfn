require 'sfn'

module Sfn
  class Callback
    class StackPolicy < Callback

      attr_reader :policies

      def initialize(*args)
        super
        @policies = Smash.new
      end

      def submit_policy(args)
        ui.warn "Policy submission not currently enabled!"
        ui.info "Currently cached policies for upload: #{@policies.inspect}"
      end
      alias_method :after_create, :submit_policy
      alias_method :after_update, :submit_policy

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

    end
  end
end
