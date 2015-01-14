require 'sparkle_formation'
require 'pathname'
require 'sfn'

module Sfn
  module Command
    # Cloudformation create command
    class Create < Command

      include Sfn::CommandModule::Base
      include Sfn::CommandModule::Template
      include Sfn::CommandModule::Stack

      # Run the stack creation command
      def execute!
        name = name_args.first
        unless(name)
          ui.fatal "Formation name must be specified!"
          exit 1
        end
        if(config[:template])
          file = config[:template]
        else
          file = load_template_file
          nested_stacks_unpack = file.delete('sfn_nested_stack')
        end
        ui.info "#{ui.color('Cloud Formation:', :bold)} #{ui.color('create', :green)}"
        stack_info = "#{ui.color('Name:', :bold)} #{name}"
        if(config[:path])
          stack_info << " #{ui.color('Path:', :bold)} #{config[:file]}"
        end

        unless(config[:print_only])
          ui.info "  -> #{stack_info}"
        end

        if(nested_stacks_unpack)
          unpack_nesting(name, file, :create)
        else

          stack = provider.connection.stacks.build(
            config[:options].dup.merge(
              :name => name,
              :template => file
            )
          )

          apply_stacks!(stack)
          stack.template = Sfn::Utils::StackParameterScrubber.scrub!(stack.template)

          if(config[:print_only])
            ui.info _format_json(translate_template(stack.template))
            return
          end

          populate_parameters!(stack.template)
          stack.parameters = config[:parameters]

          stack.template = translate_template(stack.template)
          stack.save

        end

        if(stack)
          if(config[:poll])
            poll_stack(stack.name)
            stack = provider.connection.stacks.get(name)

            if(stack.reload.success?)
              ui.info "Stack create complete: #{ui.color('SUCCESS', :green)}"
              namespace.const_val(:Describe).new({:outputs => true}, [name]).execute!
            else
              ui.fatal "Create of new stack #{ui.color(name, :bold)}: #{ui.color('FAILED', :red, :bold)}"
              ui.info ""
              namespace.const_val(:Inspect).new({:instance_failure => true}, [name]).execute!
              raise
            end
          else
            ui.warn 'Stack state polling has been disabled.'
            ui.info "Stack creation initialized for #{ui.color(name, :green)}"
          end
        end
      end

      # Apply any defined remote stacks
      #
      # @param stack [Miasma::Models::Orchestration::Stack]
      # @return [Miasma::Models::Orchestration::Stack]
      def apply_stacks!(stack)
        remote_stacks = config.fetch(:apply_stacks, [])
        remote_stacks.each do |stack_name|
          remote_stack = provider.connection.stacks.get(stack_name)
          if(remote_stack)
            stack.apply_stack(remote_stack)
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
