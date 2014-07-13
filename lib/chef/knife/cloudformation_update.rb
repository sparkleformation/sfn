require 'knife-cloudformation'

class Chef
  class Knife
    class CloudformationUpdate < Knife

      include KnifeCloudformation::Knife::Base
      include KnifeCloudformation::Knife::Template
      include KnifeCloudformation::Knife::Stack

      option(:file_path_prompt,
        :long => '--[no-]file-path-prompt',
        :description => 'Interactive prompt for template path discovery',
        :boolean => true,
        :default => false,
        :proc => lambda {|val|
          Chef::Config[:knife][:cloudformation][:file_path_prompt] = val
        }
      )

      banner 'knife cloudformation update NAME'

      # Run the stack creation command
      def run
        name = name_args.first
        unless(name)
          ui.fatal "Formation name must be specified!"
          exit 1
        end

        stack = provider.stacks.get(name)

        if(stack)
          ui.info "#{ui.color('Cloud Formation:', :bold)} #{ui.color('update', :green)}"
          file = load_template_file(:allow_missing)
          stack_info = "#{ui.color('Name:', :bold)} #{name}"

          if(Chef::Config[:knife][:cloudformation][:file])
            stack_info << " #{ui.color('Path:', :bold)} #{Chef::Config[:knife][:cloudformation][:file]}"
            if(Chef::Config[:knife][:cloudformation][:disable_processing])
              stack_info << " #{ui.color('(not pre-processed)', :yellow)}"
            end
          else
            stack_info << " #{ui.color('(no temlate update)', :yellow)}"
            file = _from_json(stack.template)
          end
          ui.info "  -> #{stack_info}"

          redefault_stack_parameters(file, stack)

          populate_parameters!(file)
          file = translate_template(file)

          stack.template = file
          stack.parameters = Chef::Config[:knife][:cloudformation][:parameters]
          stack.update

          if(Chef::Config[:knife][:cloudformation][:poll])
            poll_stack(stack)
            if(stack.success?)
              ui.info "Stack update complete: #{ui.color('SUCCESS', :green)}"
              knife_output = Chef::Knife::CloudformationDescribe.new
              knife_output.name_args.push(name)
              knife_output.config[:outputs] = true
              knife_output.run
            else
              ui.fatal "Update of stack #{ui.color(name, :bold)}: #{ui.color('FAILED', :red, :bold)}"
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
        else
          ui.fatal "Failed to locate requested stack: #{ui.color(name, :red, :bold)}"
          exit -1
        end
      end

      # Update default values for parameters in template with
      # currently used parameters on the existing stack
      #
      # @param template [Hash] stack template
      # @param stack [Fog::Orchestration::Stack]
      # @return [Hash]
      def redefault_stack_parameters(template, stack)
        stack.parameters.each do |key, value|
          if(template['Parameters'][key])
            template['Parameters'][key]['Default'] = value
          end
        end
        template
      end

    end
  end
end
