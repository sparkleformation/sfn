require 'sfn'

module Sfn
  module ApiProvider

    module Terraform

      # Disable remote template storage
      def store_template(*_)
      end

      # No formatting required on stack results
      def format_nested_stack_results(*_)
        {}
      end

      # Extract current parameters from parent template
      #
      # @param stack [SparkleFormation]
      # @param stack_name [String]
      # @param c_stack [Miasma::Models::Orchestration::Stack]
      # @return [Hash]
      def extract_current_nested_template_parameters(stack, stack_name, c_stack)
        if(c_stack && c_stack.data[:parent_stack])
          c_stack.data[:parent_stack].sparkleish_template(:remove_wrapper).fetch(
            :resources, stack_name, :properties, :parameters, Smash.new
          )
        elsif(stack.parent)
          val = stack.parent.compile.resources.set!(stack_name).properties
          val.nil? ? Smash.new : val._dump
        else
          Smash.new
        end
      end

      # Disable parameter validate as we can't adjust them without template modifications
      def validate_stack_parameter(*_)
        true
      end

      # Determine if parameter was set via intrinsic function
      #
      # @param val [Object]
      # @return [TrueClass, FalseClass]
      def function_set_parameter?(val)
        if(val)
          val.start_with?('${')
        end
      end

      # Override requirement of nesting bucket
      def validate_nesting_bucket!
        true
      end

      # Override template content extraction to disable scrub behavior
      #
      # @param thing [SparkleFormation, Hash]
      # @return [Hash]
      def template_content(thing, *_)
        if(thing.is_a?(SparkleFormation))
          config[:sparkle_dump] ? thing.sparkle_dump : thing.dump
        else
          thing
        end
      end

    end

  end
end
