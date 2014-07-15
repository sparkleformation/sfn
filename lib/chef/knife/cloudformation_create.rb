require 'sparkle_formation'
require 'pathname'
require 'knife-cloudformation'

class Chef
  class Knife
    # Cloudformation create command
    class CloudformationCreate < Knife

      include KnifeCloudformation::Knife::Base
      include KnifeCloudformation::Knife::Template
      include KnifeCloudformation::Knife::Stack

      banner 'knife cloudformation create NAME'

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
      option(:notifications,
        :long => '--notification ARN',
        :description => 'Add notification ARN. Can be used multiple times.',
        :proc => lambda {|val|
          Chef::Config[:knife][:cloudformation][:options][:notification_ARNs] ||= []
          Chef::Config[:knife][:cloudformation][:options][:notification_ARNs].push(val).uniq!
        }
      )
      option(:print_only,
        :long => '--print-only',
        :description => 'Print template and exit'
      )

      %w(rollback).each do |key|
        if(Chef::Config[:knife][:cloudformation][key].nil?)
          Chef::Config[:knife][:cloudformation][key] = true
        end
      end

      # Run the stack creation command
      def run
        name = name_args.first
        unless(name)
          ui.fatal "Formation name must be specified!"
          exit 1
        end
        if(Chef::Config[:knife][:cloudformation][:template])
          file = Chef::Config[:knife][:cloudformation][:template]
        else
          file = load_template_file
        end
        ui.info "#{ui.color('Cloud Formation:', :bold)} #{ui.color('create', :green)}"
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
            ui.info "Stack create complete: #{ui.color('SUCCESS', :green)}"
            knife_output = Chef::Knife::CloudformationDescribe.new
            knife_output.name_args.push(name)
            knife_output.config[:outputs] = true
            knife_output.run
          else
            ui.fatal "Create of new stack #{ui.color(name, :bold)}: #{ui.color('FAILED', :red, :bold)}"
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

    end
  end
end
