require 'sfn'
require 'sparkle_formation'

module Sfn
  module CommandModule
    # Stack handling helper methods
    module Stack

      module InstanceMethods

        # maximum number of attempts to get valid parameter value
        MAX_PARAMETER_ATTEMPTS = 5

        # Unpack nested stack and run action on each stack, applying
        # the previous stacks automatically
        #
        # @param name [String] container stack name
        # @param file [Hash] stack template
        # @param action [String] create or update
        # @return [TrueClass]
        def unpack_nesting(name, file, action)

          config.apply_stacks ||= []
          file['Resources'].each do |stack_resource_name, stack_resource|

            nested_stack_name = "#{name}-#{stack_resource_name}"
            nested_stack_template = stack_resource['Properties']['Stack']

            namespace.const_get(action.to_s.capitalize).new(
              Smash.new(
                :print_only => config[:print_only],
                :template => nested_stack_template,
                :parameters => config.fetch(:parameters, Smash.new).to_smash,
                :apply_stacks => config[:apply_stacks]
              ),
              [nested_stack_name]
            ).execute!
            unless(config[:print_only])
              config[:apply_stacks].push(nested_stack_name).uniq!
            end
            config[:template] = nil
            provider.connection.stacks.reload

          end

          true
        end

        # Prompt for parameter values and store result
        #
        # @param stack [Hash] stack template
        # @return [Hash]
        def populate_parameters!(stack, current_params={})
          if(config[:interactive_parameters])
            if(stack['Parameters'])
              unless(config.get(:options, :parameters))
                config.set(:options, :parameters, Smash.new)
              end
              stack.fetch('Parameters', {}).each do |k,v|
                next if config[:options][:parameters][k]
                attempt = 0
                valid = false
                until(valid)
                  attempt += 1
                  default = config[:options][:parameters].fetch(
                    k, current_params.fetch(
                      k, v['Default']
                    )
                  )
                  answer = ui.ask_question("#{k.split(/([A-Z]+[^A-Z]*)/).find_all{|s|!s.empty?}.join(' ')}: ", :default => default)
                  validation = Sfn::Utils::StackParameterValidator.validate(answer, v)
                  if(validation == true)
                    unless(answer == default)
                      config[:options][:parameters][k] = answer
                    end
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
          end
          stack
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
