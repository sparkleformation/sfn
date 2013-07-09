require 'knife-cloudformation/sparkle_formation'
require 'chef/knife/cloudformation_base'

class Chef
  class Knife
    class CloudformationCreate < CloudformationBase

      banner 'knife cloudformation create NAME'

      include CloudformationDefault
      
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
        :proc => lambda {|val| Chef::Config[:knife][:cloudformation][:options][:enable_processing] = true }
      )
      option(:disable_polling,
        :long => '--disable-polling',
        :description => 'Disable stack even polling.',
        :proc => lambda {|val| Chef::Config[:knife][:cloudformation][:options][:disable_polling] = true }
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
      
      def run
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
        ui.info "#{ui.color('Cloud Formation: ', :bold)} #{ui.color('CREATE', :green)}"
        ui.info "  -> #{ui.color('Name:', :bold)} #{name} #{ui.color('Path:', :bold)} #{Chef::Config[:knife][:cloudformation][:file]} #{ui.color('(not pre-processed)', :yellow) if Chef::Config[:knife][:cloudformation][:disable_processing]}"
        stack = build_stack(file)
        create_stack(name, stack)
        unless(Chef::Config[:knife][:cloudformation][:disable_polling])
          poll_stack(name)
        else
          ui.warn 'Stack state polling has been disabled.'
        end
        ui.info "Stack creation complete: #{ui.color('SUCCESS', :green)}"
      end

      def build_stack(template)
        stack = Mash.new
        Chef::Config[:knife][:cloudformation][:options].each do |key, value|
          format_key = key.split('_').map(&:capitalize).join
          case value
          when Hash
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
            stack[format_key] = value
          end
        end
        populate_parameters!(template)
        stack['TemplateBody'] = Chef::JSONCompat.to_json(template)
        stack
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
          ui.fatal "Failed to create stack #{name}. Reason: #{e}"
          _debug(e, "Generated template used:\n#{stack.inspect}")
          exit 1
        end
      end

      def poll_stack(name)
        knife_events = Chef::Knife::CloudformationEvents.new
        knife_events.name_args.push(name)
        Chef::Config[:knife][:cloudformation][:poll] = true
        knife_events.run
        unless(create_successful?(name))
          ui.fatal "Creation of new stack #{ui.color(name, :bold)}: #{ui.color('FAILED', :red, :bold)}"
          exit 1
        end
      end
      
      def create_in_progress?(name)
        stack_status(name) == 'CREATE_IN_PROGRESS'
      end

      def create_successful?(name)
        stack_status(name) == 'CREATE_COMPLETE'
      end
    end
  end
end
