require 'knife-cloudformation/sparkle_formation'
require 'chef/knife/cloudformation_base'

class Chef
  class Knife
    class CloudformationCreate < CloudformationBase

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
              option(:disable_rollback,
                :short => '-R',
                :long => '--disable-rollback',
                :description => 'Disable rollback on stack creation failure',
                :proc => lambda {|val| Chef::Config[:knife][:cloudformation][:options][:disable_rollback] = true }
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
              option(:enable_processing,
                :long => '--enable-processing',
                :description => 'Call the unicorns.',
                :proc => lambda {|val| Chef::Config[:knife][:cloudformation][:enable_processing] = true }
              )
              option(:disable_polling,
                :long => '--disable-polling',
                :description => 'Disable stack even polling.',
                :proc => lambda {|val| Chef::Config[:knife][:cloudformation][:disable_polling] = true }
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
              option(:disable_interactive_parameters,
                :long => '--no-parameter-prompts',
                :description => 'Do not prompt for input on dynamic parameters'
              )

              option(:print_only,
                :long => '--print-only',
                :description => 'Print template and exit'
              )
            end
          end
        end
      end

      include CloudformationDefault
      include Options
      
      def run
        @action_type = self.class.name.split('::').last.sub('Cloudformation', '').upcase
        unless(File.exists?(Chef::Config[:knife][:cloudformation][:file].to_s))
          ui.fatal "Invalid formation file path provided: #{Chef::Config[:knife][:cloudformation][:file]}"
          exit 1
        end
        name = name_args.first
        if(Chef::Config[:knife][:cloudformation][:enable_processing])
          file = KnifeCloudformation::SparkleFormation.compile(Chef::Config[:knife][:cloudformation][:file])
        else
          file = _from_json(File.read(Chef::Config[:knife][:cloudformation][:file]))
        end
        ui.info "#{ui.color('Cloud Formation: ', :bold)} #{ui.color(action_type, :green)}"
        ui.info "  -> #{ui.color('Name:', :bold)} #{name} #{ui.color('Path:', :bold)} #{Chef::Config[:knife][:cloudformation][:file]} #{ui.color('(not pre-processed)', :yellow) if Chef::Config[:knife][:cloudformation][:disable_processing]}"
        stack = build_stack(file)
        if(config[:print_only])
          ui.warn 'Print only requested'
          ui.info _format_json(stack['TemplateBody'])
          exit 1
        end
        create_stack(name, stack)
        unless(Chef::Config[:knife][:cloudformation][:disable_polling])
          poll_stack(name)
        else
          ui.warn 'Stack state polling has been disabled.'
        end
        ui.info "Stack #{action_type} complete: #{ui.color('SUCCESS', :green)}"
      end

      def build_stack(template)
        stack = Mash.new
        populate_parameters!(template)
        Chef::Config[:knife][:cloudformation][:options].each do |key, value|
          format_key = key.split('_').map(&:capitalize).join
          stack[format_key] = value
=begin          
          case value
          when Hash && key.to_sym != :parameters
            i = 1
            value.each do |k, v|
              stack["#{format_key}.member.#{i}.#{format_key[0, (format_key.length - 1)]}Key"] = k
              stack["#{format_key}.member.#{i}.#{format_key[0, (format_key.length - 1)]}Value"] = v
            end
          when Array
            value.each_with_index do |v, i|
              stack["#{format_key}.member.#{i+1}"] = v
            end
          else

          end
=end
        end
        enable_capabilities!(stack, template)
        stack['TemplateBody'] = Chef::JSONCompat.to_json(template)
        stack
      end

      # Currently only checking for IAM resources since that's all
      # that is supported for creation
      def enable_capabilities!(stack, template)
        found = Array(template['Resources']).detect do |resource_name, resource|
          resource['Type'].start_with?('AWS::IAM')
        end
        if(found)
          stack['Capabilities'] = ['CAPABILITY_IAM']
        end
      end
      
      def populate_parameters!(stack)
        unless(config[:disable_interactive_parameters])
          if(stack['Parameters'])
            Chef::Config[:knife][:cloudformation][:options][:parameters] ||= Mash.new
            stack['Parameters'].each do |k,v|
              valid = false
              until(valid)
                default = Chef::Config[:knife][:cloudformation][:options][:parameters][k] || v['Default']
                answer = ui.ask_question("#{k.split(/([A-Z]+[^A-Z]*)/).find_all{|s|!s.empty?}.join(' ')} ", :default => default)
                if(v['AllowedValues'])
                  valid = v['AllowedValues'].include?(answer)
                else
                  valid = true
                end
                if(valid)
                  Chef::Config[:knife][:cloudformation][:options][:parameters][k] = answer
                else
                  ui.error "Not an allowed value: #{v['AllowedValues'].join(', ')}"
                end
              end
            end
          end
        end
      end
      
      def create_stack(name, stack)
        begin
          res = aws_con.create_stack(name, stack)
        rescue => e
          ui.fatal "Failed to #{action_type} stack #{name}. Reason: #{e}"
          _debug(e, "Generated template used:\n#{_format_json(stack['TemplateBody'])}")
          exit 1
        end
      end

      def poll_stack(name)
        knife_events = Chef::Knife::CloudformationEvents.new
        knife_events.name_args.push(name)
        Chef::Config[:knife][:cloudformation][:poll] = true
        knife_events.run
        unless(action_successful?(name))
          ui.fatal "#{action_type} of new stack #{ui.color(name, :bold)}: #{ui.color('FAILED', :red, :bold)}"
          exit 1
        end
      end
      
      def action_in_progress?(name)
        stack_status(name) == 'CREATE_IN_PROGRESS'
      end

      def action_successful?(name)
        stack_status(name) == 'CREATE_COMPLETE'
      end
    end
  end
end
