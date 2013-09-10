require 'knife-cloudformation/sparkle_formation'
require 'chef/knife/cloudformation_base'

class Chef
  class Knife
    class CloudformationCreate < Knife

      include KnifeCloudformation::KnifeBase

      banner 'knife cloudformation create NAME'

      module Options
        class << self
          def included(klass)
            klass.class_eval do

              attr_accessor :action_type

              option(:parameter,
                :short => '-p KEY:VALUE',
                :long => '--parameter KEY:VALUE',
                :description => 'Set parameter. Can be used multiple times.',
                :proc => lambda {|val|
                  key,value = val.split(':')
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
                :proc => lambda {|val| Chef::Config[:knife][:cloudformation][:options][:disable_rollback] = val }
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
              option(:processing,
                :long => '--[no-]processing',
                :description => 'Call the unicorns and explode the glitter bombs',
                :boolean => true,
                :default => false,
                :proc => lambda {|val| Chef::Config[:knife][:cloudformation][:processing] = val }
              )
              option(:polling,
                :long => '--[no-]polling',
                :description => 'Enable stack event polling.',
                :boolean => true,
                :default => true,
                :proc => lambda {|val| Chef::Config[:knife][:cloudformation][:polling] = val }
              )
              option(:notifications,
                :long => '--notification ARN',
                :description => 'Add notification ARN. Can be used multiple times.',
                :proc => lambda {|val|
                  Chef::Config[:knife][:cloudformation][:options][:notification_ARNs] ||= []
                  Chef::Config[:knife][:cloudformation][:options][:notification_ARNs].push(val).uniq!
                }
              )
              option(:file,
                :short => '-f PATH',
                :long => '--file PATH',
                :description => 'Path to Cloud Formation to process',
                :proc => lambda {|val|
                  Chef::Config[:knife][:cloudformation][:file] = val
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

      def run
        @action_type = self.class.name.split('::').last.sub('Cloudformation', '').upcase
        unless(File.exists?(Chef::Config[:knife][:cloudformation][:file].to_s))
          ui.fatal "Invalid formation file path provided: #{Chef::Config[:knife][:cloudformation][:file]}"
          exit 1
        end
        name = name_args.first
        if(Chef::Config[:knife][:cloudformation][:processing])
          file = KnifeCloudformation::SparkleFormation.compile(Chef::Config[:knife][:cloudformation][:file])
        else
          file = _from_json(File.read(Chef::Config[:knife][:cloudformation][:file]))
        end
        ui.info "#{ui.color('Cloud Formation: ', :bold)} #{ui.color(action_type, :green)}"
        ui.info "  -> #{ui.color('Name:', :bold)} #{name} #{ui.color('Path:', :bold)} #{Chef::Config[:knife][:cloudformation][:file]} #{ui.color('(not pre-processed)', :yellow) if Chef::Config[:knife][:cloudformation][:disable_processing]}"
        populate_parameters!(file)
        stack_def = KnifeCloudformation::AwsCommons::Stack.build_stack_definition(file, Chef::Config[:knife][:cloudformation][:options])
        if(config[:print_only])
          ui.warn 'Print only requested'
          ui.info _format_json(stack_def['TemplateBody'])
          exit 1
        end
        aws.create_stack(name, stack_def)
        if(Chef::Config[:knife][:cloudformation][:polling])
          poll_stack(name)
          if(stack(name).complete?)
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
            knife_inspect.config[:inspect_failure] = true
            knife_inspect.run
            exit 1
          end
        else
          ui.warn 'Stack state polling has been disabled.'
          ui.info "Stack creation initialized for #{ui.color(name, :green)}"
        end
      end

      def populate_parameters!(stack)
        if(Chef::Config[:knife][:cloudformation][:interactive_parameters])
          if(stack['Parameters'])
            Chef::Config[:knife][:cloudformation][:options][:parameters] ||= Mash.new
            stack['Parameters'].each do |k,v|
              valid = false
              until(valid)
                default = Chef::Config[:knife][:cloudformation][:options][:parameters][k] || v['Default']
                answer = ui.ask_question("#{k.split(/([A-Z]+[^A-Z]*)/).find_all{|s|!s.empty?}.join(' ')} ", :default => default)
                validation = KnifeCloudformation::AwsCommons::Stack::ParameterValidator.validate(answer, v)
                if(validation == true)
                  Chef::Config[:knife][:cloudformation][:options][:parameters][k] = answer
                  valid = true
                else
                  validation.each do |validation_error|
                    ui.error validation.last
                  end
                end
              end
            end
          end
        end
      end

    end
  end
end
