require 'knife-cloudformation'
require 'sparkle_formation'

module KnifeCloudformation
  module Knife
    # Stack handling helper methods
    module Stack

      module InstanceMethods

        # maximum number of attempts to get valid parameter value
        MAX_PARAMETER_ATTEMPTS = 5

        # Prompt for parameter values and store result
        #
        # @param stack [Hash] stack template
        # @return [Hash]
        def populate_parameters!(stack)
          if(Chef::Config[:knife][:cloudformation][:interactive_parameters])
            if(stack['Parameters'] || stack['parameters'])
              Chef::Config[:knife][:cloudformation][:options][:parameters] ||= Mash.new
              stack.fetch('Parameters', stack.fetch('parameters', {})).each do |k,v|
                next if Chef::Config[:knife][:cloudformation][:options][:parameters][k]
                attempt = 0
                valid = false
                until(valid)
                  attempt += 1
                  default = Chef::Config[:knife][:cloudformation][:options][:parameters][k] || v['Default'] || v['default']
                  answer = ui.ask_question("#{k.split(/([A-Z]+[^A-Z]*)/).find_all{|s|!s.empty?}.join(' ')}: ", :default => default)
                  validation = KnifeCloudformation::Utils::StackParameterValidator.validate(answer, v)
                  if(validation == true)
                    Chef::Config[:knife][:cloudformation][:options][:parameters][k] = answer
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
