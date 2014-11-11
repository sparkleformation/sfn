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
          else
            stack_info << " #{ui.color('(no temlate update)', :yellow)}"
          end
          ui.info "  -> #{stack_info}"

          apply_stacks!(stack)

          if(file)
            redefault_stack_parameters(file, stack)
            populate_parameters!(file)
            file = translate_template(file)
            stack.template = file
            stack.parameters = Chef::Config[:knife][:cloudformation][:parameters]
          else
            stack_parameters_update!(stack)
          end

          stack.save

          if(Chef::Config[:knife][:cloudformation][:poll])
            poll_stack(stack.name)
            provider.fetch_stacks
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
          remote_stack = provider.stacks.get(stack_name)
          if(remote_stack)
            remote_stack.parameters.each do |key, value|
              next if Chef::Config[:knife][:cloudformation][:stacks][:ignore_parameters].include?(key)
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

      # Update parameters within existing stack
      #
      # @param stack [Miasma::Models::Orchestration::Stack]
      # @return [Miasma::Models::Orchestration::Stack]
      def stack_parameters_update!(stack)
        stack.parameters.each do |key, value|
          answer = ui.ask_question("#{key.split(/([A-Z]+[^A-Z]*)/).find_all{|s|!s.empty?}.join(' ')}: ", :default => value)
          stack.parameters[key] = answer
        end
      end

    end
  end
end
