require 'sfn'
require 'sparkle_formation'

module Sfn
  module CommandModule
    # Stack handling helper methods
    module Stack

      module InstanceMethods

        # unpacked stack name joiner/identifier
        UNPACK_NAME_JOINER = '-sfn-'
        # maximum number of attempts to get valid parameter value
        MAX_PARAMETER_ATTEMPTS = 5

        # Apply any defined remote stacks
        #
        # @param stack [Miasma::Models::Orchestration::Stack]
        # @return [Miasma::Models::Orchestration::Stack]
        def apply_stacks!(stack)
          remote_stacks = [config[:apply_stack]].flatten.compact
          remote_stacks.each do |stack_name|
            remote_stack = provider.connection.stacks.get(stack_name)
            if(remote_stack)
              apply_nested_stacks!(remote_stack, stack)
              stack.apply_stack(remote_stack)
            else
              apply_unpacked_stack!(stack_name, stack)
            end
          end
          stack
        end

        # Detect nested stacks and apply
        #
        # @param remote_stack [Miasma::Models::Orchestration::Stack] stack to inspect for nested stacks
        # @param stack [Miasma::Models::Orchestration::Stack] current stack
        # @return [Miasma::Models::Orchestration::Stack]
        def apply_nested_stacks!(remote_stack, stack)
          remote_stack.resources.all.each do |resource|
            if(resource.type == 'AWS::CloudFormation::Stack')
              nested_stack = resource.expand
              apply_nested_stacks!(nested_stack, stack)
              stack.apply_stack(nested_stack)
            end
          end
          stack
        end

        # Apply all stacks from an unpacked stack
        #
        # @param stack_name [String] name of parent stack
        # @param stack [Miasma::Models::Orchestration::Stack]
        # @return [Miasma::Models::Orchestration::Stack]
        def apply_unpacked_stack!(stack_name, stack)
          result = provider.connection.stacks.all.find_all do |remote_stack|
            remote_stack.name.start_with?("#{stack_name}#{UNPACK_NAME_JOINER}")
          end.sort_by(&:name).map do |remote_stack|
            stack.apply_stack(remote_stack)
          end
          unless(result.empty?)
            stack
          else
            ui.error "Failed to apply requested stack. Unable to locate. (#{stack_name})"
            raise "Failed to locate stack: #{stack_name}"
          end
        end

        # Unpack nested stack and run action on each stack, applying
        # the previous stacks automatically
        #
        # @param name [String] container stack name
        # @param file [Hash] stack template
        # @param action [String] create or update
        # @return [TrueClass]
        def unpack_nesting(name, file, action)
          config[:apply_stacks] ||= []
          stack_count = 0
          file['Resources'].each do |stack_resource_name, stack_resource|

            nested_stack_name = "#{name}#{UNPACK_NAME_JOINER}#{Kernel.sprintf('%0.3d', stack_count)}-#{stack_resource_name}"
            nested_stack_template = stack_resource['Properties']['Stack']

            namespace.const_get(action.to_s.capitalize).new(
              Smash.new(
                :print_only => config[:print_only],
                :template => nested_stack_template,
                :parameters => config.fetch(:parameters, Smash.new).to_smash,
                :apply_stacks => config[:apply_stacks],
                :options => config[:options]
              ),
              [nested_stack_name]
            ).execute!
            unless(config[:print_only])
              config[:apply_stacks].push(nested_stack_name).uniq!
            end
            config[:template] = nil
            provider.connection.stacks.reload
            stack_count += 1
          end

          true
        end

        # Prompt for parameter values and store result
        #
        # @param sparkle [SparkleFormation]
        # @return [Hash]
        def populate_parameters!(sparkle, current_params={})
          parameter_prefix = sparkle.root? ? [] : (sparkle.root_path - [sparkle.root]).map do |s|
            Bogo::Utility.camel(s.name)
          end
          stack_parameters = sparkle.compile.parameters
          unless(stack_parameters.nil?)
            stack_parameters = stack_parameters._dump
            if(config.get(:parameter).is_a?(Array))
              config[:parameter] = Smash[
                *config.get(:parameter).map(&:to_a).flatten
              ]
            end
            if(config.get(:parameters))
              config.set(:parameters,
                config.get(:parameters).merge(config.fetch(:parameter, Smash.new))
              )
            else
              config.set(:parameters, config.fetch(:parameter, Smash.new))
            end
            stack_parameters.each do |k,v|
              ns_k = (parameter_prefix + [k]).join('__')
              next if config[:parameters][ns_k]
              if(current_params[k].is_a?(Hash))
                # NOTE: direct set dumps the stack (nfi). Smash will
                # auto dup it, and works, so yay i guess.
                config[:parameters][ns_k] = Smash.new(current_params[k])
                valid = true
              else
                valid = false
              end
              attempt = 0
              valid = false
              until(valid)
                attempt += 1
                default = config[:parameters].fetch(
                  ns_k, current_params.fetch(
                    k, v['Default']
                  )
                )
                if(config[:interactive_parameters])
                  answer = ui.ask_question("#{k.split(/([A-Z]+[^A-Z]*)/).find_all{|s|!s.empty?}.join(' ')}", :default => default)
                else
                  answer = default
                end
                validation = Sfn::Utils::StackParameterValidator.validate(answer, v)
                if(validation == true)
                  config[:parameters][ns_k] = answer
                  valid = true
                else
                  validation.each do |validation_error|
                    ui.error validation_error.last
                  end
                end
                if(attempt > MAX_PARAMETER_ATTEMPTS)
                  ui.fatal 'Failed to receive allowed parameter!'
                  exit 1
                end
              end
            end
          end
          Smash[
            config.fetch(:parameters, {}).map do |k,v|
              strip_key = k.sub(/#{parameter_prefix.join('__')}_{2}?/, '')
              unless(strip_key.include?('__'))
                [strip_key, v]
              end
            end.compact
          ]
        end

      end

      module ClassMethods
      end

      # Load methods into class and define options
      #
      # @param klass [Class]
      def self.included(klass)
        klass.class_eval do
          extend Sfn::CommandModule::Stack::ClassMethods
          include Sfn::CommandModule::Stack::InstanceMethods
        end
      end

    end
  end
end
