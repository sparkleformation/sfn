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
      option(:apply_stacks,
        :long => '--apply-stack NAME_OR_ID',
        :description => 'Autofill parameters using existing stack outputs. Can be used multiple times',
        :proc => lambda {|val|
          Chef::Config[:knife][:cloudformation][:update] ||= Mash.new
          Chef::Config[:knife][:cloudformation][:update][:apply_stacks] ||= []
          Chef::Config[:knife][:cloudformation][:update][:apply_stacks].push(val).uniq!
        }
      )

      banner 'knife cloudformation update NAME'

      # Run the stack creation command
      def _run
        name = name_args.first
        unless(name)
          ui.fatal "Formation name must be specified!"
          exit 1
        end

        stack_info = "#{ui.color('Name:', :bold)} #{name}"

        if(Chef::Config[:knife][:cloudformation][:file])
          file = load_template_file
          stack_info << " #{ui.color('Path:', :bold)} #{Chef::Config[:knife][:cloudformation][:file]}"
          nested_stacks = file.delete('sfn_nested_stack')
        end

        if(nested_stacks)

          unpack_nesting(name, file, :update)

        else
          stack = provider.connection.stacks.get(name)

          if(stack)
            ui.info "#{ui.color('Cloud Formation:', :bold)} #{ui.color('update', :green)}"

            unless(file)
              if(Chef::Config[:knife][:cloudformation][:template])
                file = Chef::Config[:knife][:cloudformation][:template]
                stack_info << " #{ui.color('(template provided)', :green)}"
              else
                stack_info << " #{ui.color('(no template update)', :yellow)}"
              end
            end
            ui.info "  -> #{stack_info}"

            apply_stacks!(stack)

            if(file)
              populate_parameters!(file, stack.parameters)
              stack.template = translate_template(file)
              stack.parameters = Chef::Config[:knife][:cloudformation][:parameters]
              stack.template = KnifeCloudformation::Utils::StackParameterScrubber.scrub!(stack.template)
            else
              populate_parameters!(stack.template, stack.parameters)
              stack.parameters = Chef::Config[:knife][:cloudformation][:parameters]
            end

            begin
              stack.save
            rescue Miasma::Error::ApiError::RequestError => e
              if(e.message.downcase.include?('no updates')) # :'(
                ui.warn "No updates detected for stack (#{stack.name})"
              else
                raise
              end
            end

            if(Chef::Config[:knife][:cloudformation][:poll])
              poll_stack(stack.name)
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
              ui.info "Stack update initialized for #{ui.color(name, :green)}"
            end
          else
            ui.fatal "Failed to locate requested stack: #{ui.color(name, :red, :bold)}"
            exit -1
          end

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

      # Apply any defined remote stacks
      #
      # @param stack [Miasma::Models::Orchestration::Stack]
      # @return [Miasma::Models::Orchestration::Stack]
      def apply_stacks!(stack)
        remote_stacks = Chef::Config[:knife][:cloudformation].
          fetch(:update, {}).fetch(:apply_stacks, [])
        remote_stacks.each do |stack_name|
          remote_stack = provider.connection.stacks.get(stack_name)
          if(remote_stack)
            remote_stack.parameters.each do |key, value|
              next if Chef::Config[:knife][:cloudformation].fetch(:stacks, {}).fetch(:ignore_parameters, []).include?(key)
              if(stack.parameters.has_key?(key))
                stack.parameters[key] = value
              end
            end
          else
            ui.error "Failed to apply requested stack. Unable to locate. (#{stack_name})"
            exit 1
          end
        end
        stack
      end

    end
  end
end
