require 'sparkle_formation'
require 'pathname'
require 'knife-cloudformation'

class Chef
  class Knife
    # Cloudformation create command
    # @note this class is implemented to be subclassed for things like `update`
    class CloudformationCreate < Knife

      include KnifeCloudformation::Knife::Base
      include KnifeCloudformation::Knife::Template

      banner 'knife cloudformation create NAME'

      # Container for CLI options
      module Options
        class << self

          # Add CLI option to class
          #
          # @param klass [Class]
          def included(klass)
            klass.class_eval do

              attr_accessor :action_type

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
              option(:timeout,
                :short => '-t MIN',
                :long => '--timeout MIN',
                :description => 'Set timeout for stack creation',
                :proc => lambda {|val|
                  Chef::Config[:knife][:cloudformation][:options][:timeout_in_minutes] = val
                }
              )
              option(:rollback,
                :short => '-R',
                :long => '--[no]-rollback',
                :description => 'Rollback on stack creation failure',
                :boolean => true,
                :default => true,
                :proc => lambda {|val| Chef::Config[:knife][:cloudformation][:options][:disable_rollback] = !val }
              )
              option(:capability,
                :short => '-C CAPABILITY',
                :long => '--capability CAPABILITY',
                :description => 'Specify allowed capabilities. Can be used multiple times.',
                :proc => lambda {|val|
                  Chef::Config[:knife][:cloudformation][:options][:capabilities] ||= []
                  Chef::Config[:knife][:cloudformation][:options][:capabilities].push(val).uniq!
                }
              )
              option(:polling,
                :long => '--[no-]poll',
                :description => 'Enable stack event polling.',
                :boolean => true,
                :default => true,
                :proc => lambda {|val| Chef::Config[:knife][:cloudformation][:poll] = val }
              )
              option(:notifications,
                :long => '--notification ARN',
                :description => 'Add notification ARN. Can be used multiple times.',
                :proc => lambda {|val|
                  Chef::Config[:knife][:cloudformation][:options][:notification_ARNs] ||= []
                  Chef::Config[:knife][:cloudformation][:options][:notification_ARNs].push(val).uniq!
                }
              )
              option(:interactive_parameters,
                :long => '--[no-]parameter-prompts',
                :boolean => true,
                :default => true,
                :description => 'Do not prompt for input on dynamic parameters',
                :default => true
              )
              option(:print_only,
                :long => '--print-only',
                :description => 'Print template and exit'
              )

              %w(rollback polling interactive_parameters).each do |key|
                if(Chef::Config[:knife][:cloudformation][key].nil?)
                  Chef::Config[:knife][:cloudformation][key] = true
                end
              end
            end
          end
        end
      end

      include Options

      # Run the stack creation command
      def run
        @action_type = self.class.name.split('::').last.sub('Cloudformation', '').upcase
        name = name_args.first
        unless(name)
          ui.fatal "Formation name must be specified!"
          exit 1
        end

        file = load_template_file

        ui.info "#{ui.color('Cloud Formation: ', :bold)} #{ui.color(action_type, :green)}"
        stack_info = "#{ui.color('Name:', :bold)} #{name}"
        if(Chef::Config[:knife][:cloudformation][:path])
          stack_info << " #{ui.color('Path:', :bold)} #{Chef::Config[:knife][:cloudformation][:file]}"
          if(Chef::Config[:knife][:cloudformation][:disable_processing])
            stack_info << " #{ui.color('(not pre-processed)', :yellow)}"
          end
        end
        ui.info "  -> #{stack_info}"
        populate_parameters!(file)
        file = translate_template(file)

        if(config[:print_only])
          ui.warn 'Print only requested'
          ui.info _format_json(file)
          exit 1
        end

        stack = provider.stacks.new(
          Chef::Config[:knife][:cloudformation][:options].dup.merge(
            :stack_name => name,
            :template => file
          )
        )
        stack.create

        if(Chef::Config[:knife][:cloudformation][:poll])
          poll_stack(stack)
          if(stack.success?)
            ui.info "Stack #{action_type} complete: #{ui.color('SUCCESS', :green)}"
            knife_output = Chef::Knife::CloudformationDescribe.new
            knife_output.name_args.push(name)
            knife_output.config[:outputs] = true
            knife_output.run
          else
            ui.fatal "#{action_type} of new stack #{ui.color(name, :bold)}: #{ui.color('FAILED', :red, :bold)}"
            ui.info ""
            knife_inspect = Chef::Knife::CloudformationInspect.new
            knife_inspect.name_args.push(name)
            knife_inspect.config[:instance_failure] = true
            knife_inspect.run
            exit 1
          end
        else
          ui.warn 'Stack state polling has been disabled.'
          ui.info "Stack creation initialized for #{ui.color(name, :green)}"
        end
      end

      # Prompt for parameter values and store result
      #
      # @param stack [Hash] stack template
      # @return [Hash]
      def populate_parameters!(stack)
        if(Chef::Config[:knife][:cloudformation][:interactive_parameters])
          if(stack['Parameters'])
            Chef::Config[:knife][:cloudformation][:options][:parameters] ||= Mash.new
            stack.fetch('Parameters', {}).each do |k,v|
              next if Chef::Config[:knife][:cloudformation][:options][:parameters][k]
              valid = false
              until(valid)
                default = Chef::Config[:knife][:cloudformation][:options][:parameters][k] || v['Default']
                answer = ui.ask_question("#{k.split(/([A-Z]+[^A-Z]*)/).find_all{|s|!s.empty?}.join(' ')}: ", :default => default)
                validation = KnifeCloudformation::AwsCommons::Stack::ParameterValidator.validate(answer, v)
                if(validation == true)
                  Chef::Config[:knife][:cloudformation][:options][:parameters][k] = answer
                  valid = true
                else
                  validation.each do |validation_error|
                    ui.error validation_error.last
                  end
                end
              end
            end
          end
        end
        stack
      end

    end
  end
end
