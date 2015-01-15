require 'knife-cloudformation'
require 'sparkle_formation'

module KnifeCloudformation
  module Knife
    # Stack handling helper methods
    module Stack

      module InstanceMethods

        # un-packed stack name joiner/identifier
        UNPACK_NAME_JOINER = '-sfn-'
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

          # @todo move this init into setup
          Chef::Config[:knife][:cloudformation][action.to_sym] ||= Mash.new
          Chef::Config[:knife][:cloudformation][action.to_sym][:apply_stacks] ||= []

          orig_params = Chef::Config[:knife][:cloudformation][:options][:parameters]

          file['Resources'].each do |stack_resource_name, stack_resource|

            nested_stack_name = "#{name}#{UNPACK_NAME_JOINER}#{stack_resource_name}"
            nested_stack_template = stack_resource['Properties']['Stack']
            Chef::Config[:knife][:cloudformation][:options][:parameters] = orig_params

            klass = Chef::Knife.const_get("Cloudformation#{action.to_s.capitalize}")
            nested_stack_runner = klass.new
            nested_stack_runner.config[:print_only] = config[:print_only]
            nested_stack_runner.name_args.push(nested_stack_name)
            Chef::Config[:knife][:cloudformation][:template] = nested_stack_template
            nested_stack_runner.run
            unless(config[:print_only])
              Chef::Config[:knife][:cloudformation][action.to_sym][:apply_stacks].push(nested_stack_name).uniq!
            end
            Chef::Config[:knife][:cloudformation][:template] = nil
            provider.connection.stacks.reload

          end

          true
        end

        # Prompt for parameter values and store result
        #
        # @param stack [Hash] stack template
        # @return [Hash]
        def populate_parameters!(stack, current_params={})
          if(Chef::Config[:knife][:cloudformation][:interactive_parameters])
            if(stack['Parameters'])
              Chef::Config[:knife][:cloudformation][:options][:parameters] ||= Mash.new
              stack.fetch('Parameters', {}).each do |k,v|
                next if Chef::Config[:knife][:cloudformation][:options][:parameters][k]
                attempt = 0
                valid = false
                until(valid)
                  attempt += 1
                  default = Chef::Config[:knife][:cloudformation][:options][:parameters].fetch(
                    k, current_params.fetch(
                      k, v['Default']
                    )
                  )
                  answer = ui.ask_question("#{k.split(/([A-Z]+[^A-Z]*)/).find_all{|s|!s.empty?}.join(' ')}: ", :default => default)
                  validation = KnifeCloudformation::Utils::StackParameterValidator.validate(answer, v)
                  if(validation == true)
                    unless(answer == default)
                      Chef::Config[:knife][:cloudformation][:options][:parameters][k] = answer
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
          extend KnifeCloudformation::Knife::Stack::ClassMethods
          include KnifeCloudformation::Knife::Stack::InstanceMethods

          option(:parameter,
            :short => '-p KEY:VALUE',
            :long => '--parameter KEY:VALUE',
            :description => 'Set parameter. Can be used multiple times.',
            :proc => lambda {|val|
              parts = val.split(':')
              key = parts.first
              value = parts[1, parts.size].join(':')
              Chef::Config[:knife][:cloudformation][:options][:parameters] ||= Mash.new
              Chef::Config[:knife][:cloudformation][:options][:parameters][key] = value
            }
          )
          option(:polling,
            :long => '--[no-]poll',
            :description => 'Enable stack event polling.',
            :boolean => true,
            :default => true,
            :proc => lambda {|val| Chef::Config[:knife][:cloudformation][:poll] = val }
          )
          option(:interactive_parameters,
            :long => '--[no-]parameter-prompts',
            :boolean => true,
            :default => true,
            :description => 'Do not prompt for input on dynamic parameters',
            :proc => lambda{|val| Chef::Config[:knife][:cloudformation][:interactive_parameters] = val }
          )
        end
      end

    end
  end
end
