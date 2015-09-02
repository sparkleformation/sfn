require 'base64'
require 'sfn'

module Sfn
  module MonkeyPatch

    # Expand stack model functionality
    module Stack

      include Bogo::AnimalStrings

      ## Status helpers

      # Check for state suffix
      #
      # @param args [String, Symbol] state suffix to check for (multiple allowed)
      # @return [TrueClass, FalseClass] true if any matches found in argument list
      def status_ends_with?(*args)
        stat = status.to_s.downcase
        !!args.map(&:to_s).map(&:downcase).detect do |suffix|
          stat.end_with?(suffix)
        end
      end

      # Check for state prefix
      #
      # @param args [String, Symbol] state prefix to check for (multiple allowed)
      # @return [TrueClass, FalseClass] true if any matches found in argument list
      def status_starts_with?(*args)
        stat = status.to_s.downcase
        !!args.map(&:to_s).map(&:downcase).detect do |prefix|
          stat.start_with?(prefix)
        end
      end

      # Check for state inclusion
      #
      # @param args [String, Symbol] state string to check for (multiple allowed)
      # @return [TrueClass, FalseClass] true if any matches found in argument list
      def status_includes?(*args)
        stat = status.to_s.downcase
        !!args.map(&:to_s).map(&:downcase).detect do |string|
          stat.include?(string)
        end
      end

      # @return [TrueClass, FalseClass] stack is in progress
      def in_progress?
        status_ends_with?(:in_progress)
      end

      # @return [TrueClass, FalseClass] stack is in complete state
      def complete?
        status_ends_with?(:complete, :failed)
      end

      # @return [TrueClass, FalseClass] stack is failed state
      def failed?
        status_ends_with?(:failed) ||
          (status_includes?(:rollback) && status_ends_with?(:complete))
      end

      # @return [TrueClass, FalseClass] stack is in success state
      def success?
        !failed? && complete?
      end

      # @return [TrueClass, FalseClass] stack is creating
      def creating?
        in_progress? && status_starts_with?(:create)
      end

      # @return [TrueClass, FalseClass] stack is deleting
      def deleting?
        in_progress? && status_starts_with?(:delete)
      end

      # @return [TrueClass, FalseClass] stack is updating
      def updating?
        in_progress? && status_starts_with?(:update)
      end

      # @return [TrueClass, FalseClass] stack is rolling back
      def rollbacking?
        in_progress? && status_starts_with?(:rollback)
      end

      # @return [String] action currently being performed
      def performing
        if(in_progress?)
          status.to_s.downcase.split('_').first.to_sym
        end
      end

      ### Color coders

      # @return [TrueClass, FalseClass] stack is in red state
      def red?
        failed? || deleting?
      end

      # @return [TrueClass, FalseClass] stack is in green state
      def green?
        success?
      end

      # @return [TrueClass, FalseClass] stack is in yellow state
      def yellow?
        !red? && !green?
      end

      # Provides color of stack state. Red is an error state, yellow
      # is a warning state and green is a success state
      #
      # @return [Symbol] color of state (:red, :yellow, :green)
      def color_state
        red? ? :red : green? ? :green : :yellow
      end

      # Provides text of stack state. Danger is an error state, warning
      # is a warning state and success is a success state
      #
      # @return [Symbol] color of state (:danger, :warning, :success)
      def text_state
        red? ? :danger : green? ? :success : :warning
      end

      # @return [String] URL safe encoded stack id
      def encoded_id
        Base64.urlsafe_encode64(id)
      end

      # Whole number representation of current completion
      #
      # @param min [Integer] lowest allowed return value (defaults 5)
      # @return [Integer] percent complete (0..100)
      def percent_complete(min = 5)
        if(in_progress?)
          total_resources = load_template.fetch('Resources', []).size
          total_complete = resources.all.find_all do |resource|
            resource.resource_status.downcase.end_with?('complete')
          end.size
          result = ((total_complete.to_f / total_resources) * 100).to_i
          result > min.to_i ? result : min
        else
          100
        end
      end

      # Apply stack outputs to current stack parameters
      #
      # @param remote_stack [Miasma::Orchestration::Stack]
      # @return [self]
      # @note setting `DisableApply` within parameter hash will
      #   prevent parameters being overridden
      def apply_stack(remote_stack, ignore_params=nil)
        default_key = 'Default'
        stack_parameters = template['Parameters']
        valid_parameters = Smash[
          stack_parameters.map do |key, val|
            unless(val['DisableApply'])
              [snake(key), key]
            end
          end.compact
        ]
        if(ignore_params)
          valid_parameters = Hash[
            valid_parameters.map do |snake_param, camel_param|
              unless(ignore_params.include?(camel_param))
                [snake_param, camel_param]
              end
            end.compact
          ]
        end
        if(persisted?)
          remote_stack.outputs.each do |output|
            if(param_key = valid_parameters[snake(output.key)])
              parameters.merge!(param_key => output.value)
            end
          end
        else
          remote_stack.outputs.each do |output|
            if(param_key = valid_parameters[snake(output.key)])
              stack_parameters[param_key][default_key] = output.value
            end
          end
        end
      end

      # Return all stacks contained within this stack
      #
      # @param recurse [TrueClass, FalseClass] recurse to fetch _all_ stacks
      # @return [Array<Miasma::Models::Orchestration::Stack>]
      def nested_stacks(recurse=true)
        resources.all.map do |resource|
          if(self.api.class.const_get(:RESOURCE_MAPPING).fetch(resource.type, {})[:api] == :orchestration)
            n_stack = resource.expand
            if(n_stack)
              n_stack.data[:logical_id] = resource.name
              n_stack.data[:parent_stack] = self
              if(recurse)
                [n_stack] + n_stack.nested_stacks(recurse)
              else
                n_stack
              end
            end
          end
        end.flatten.compact
      end

      # @return [TrueClass, FalseClass] stack contains nested stacks
      def nested?
        !!resources.detect do |resource|
          self.api.class.const_get(:RESOURCE_MAPPING).fetch(resource.type, {})[:api] == :orchestration
        end
      end

      # Return stack policy if available
      #
      # @return [Smash, NilClass]
      def policy
        if(self.api.provider == :aws) # cause this is the only one
          begin
            result = self.api.request(
              :path => '/',
              :form => Smash.new(
                'Action' => 'GetStackPolicy',
                'StackName' => self.id
              )
            )
            serialized_policy = result.get(:body, 'GetStackPolicyResult', 'StackPolicyBody')
            MultiJson.load(serialized_policy).to_smash
          rescue Miasma::Error::ApiError::RequestError => e
            if(e.response.code == 404)
              nil
            else
              raise
            end
          end
        end
      end

      # Detect the nesting style in use by the stack
      #
      # @return [Symbol, NilClass] style of nesting (:shallow, :deep)
      #   or `nil` if no nesting detected
      # @note in shallow nesting style, stack resources will not
      #   contain any direct values for parameters (which is what we
      #   are testing for)
      def nesting_style
        if(nested?)
          self.template['Resources'].find_all do |t_resource|
            t_resource['Type'] == self.api.class.const_get(:RESOURCE_MAPPING).key(self.class)
          end.detect do |t_resource|
            t_resource['Properties'].fetch('Parameters', {}).values.detect do |t_value|
              !t_value.is_a?(Hash)
            end
          end ? :deep : :shallow
        end
      end

    end
  end
end

# Infect miasma
Miasma::Models::Orchestration::Stack.send(:include, Sfn::MonkeyPatch::Stack)
