require 'base64'
require 'fog/orchestration/models/stack'
require 'knife-cloudformation'

module KnifeCloudformation
  module MonkeyPatch

    # Expand stack model functionality
    module Stack

      include KnifeCloudformation::Utils::AnimalStrings

      # Load the JSON template
      #
      # @return [Hash] loaded template
      def load_template
        if(template)
          MultiJson.load(template)
        else
          {}
        end
      end

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

      # @return [String] #stack_status alias
      def status
        stack_status
      end

      # @return [Fog::Model::Compute] nodes within this stack
      # @todo reimplement in non-aws specific manner
      def nodes
        []
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
          full_expansion!
          total_resources = load_template.fetch('Resources', []).size
          total_complete = (resources || []).find_all do |resource|
            resource.resource_status.downcase.end_with?('complete')
          end.size
          result = ((total_complete.to_f / total_resources) * 100).to_i
          result > min.to_i ? result : min
        else
          100
        end
      end

      # @param provider [KnifeCloudformation::Provider]
      # @return [KnifeCloudformation::Provider]
      def _provider(provider=nil)
        @provider ||= provider
      end

      # Expand all lazy loaded attributes and save to cache
      #
      # @return [self]
      def full_expansion!
        if(_provider)
          begin
            _provider.expand_stack(self)
          rescue => e
            attributes['Events'] ||= []
            attributes['Resources'] ||= []
            attributes['TemplateBody'] ||= ''
          end
        end
        self
      end

      # Apply stack outputs to current stack parameters
      #
      # @param remote_stack [Fog::Orchestration::Stack]
      # @return [self]
      def apply_stack(remote_stack)
        loaded_template = load_template
        default_key = loaded_template['heat_template_version'] ? 'default' : 'Default'
        stack_parameters = loaded_template.fetch('Parameters',
          loaded_template.fetch('parameters', {})
        )
        valid_parameters = Hash[
          stack_parameters.keys.map do |key|
            [snake(key), key]
          end
        ]
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
          self.template = MultiJson.dump(loaded_template)
        end
      end

    end
  end
end

# Infect fog
Fog::Orchestration::Stack.send(:include, KnifeCloudformation::MonkeyPatch::Stack)
