require 'sparkle_formation'
require 'sfn'

module Sfn
  class Command
    # Create command
    class Create < Command

      include Sfn::CommandModule::Base
      include Sfn::CommandModule::Template
      include Sfn::CommandModule::Stack

      # Run the stack creation command
      def execute!
        name_required!
        name = name_args.first
        if(config[:template])
          file = config[:template]
        else
          file = load_template_file
          nested_stacks_unpack = file.delete('sfn_nested_stack')
        end

        unless(config[:print_only])
          ui.info "#{ui.color('SparkleFormation:', :bold)} #{ui.color('create', :green)}"
        end

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

          if(config[:print_only] && !config[:apply_stacks])
            ui.puts _format_json(
              translate_template(
                Sfn::Utils::StackParameterScrubber.scrub!(file)
              )
            )
            return
          end

          stack = provider.connection.stacks.build(
            config.fetch(:options, Smash.new).dup.merge(
              :name => name,
              :template => file
            )
          )

          apply_stacks!(stack)
          stack.template = Sfn::Utils::StackParameterScrubber.scrub!(stack.template)

          if(config[:print_only])
            ui.puts _format_json(translate_template(stack.template))
            return
          end

          populate_parameters!(stack.template)
          stack.parameters = config_root_parameters

          stack.template = translate_template(stack.template)

          api_action!(:api_stack => stack) do
            stack.save
            if(config[:poll])
              poll_stack(stack.name)
              stack = provider.connection.stacks.get(name)

              if(stack.reload.state == :create_complete)
                ui.info "Stack create complete: #{ui.color('SUCCESS', :green)}"
                namespace.const_get(:Describe).new({:outputs => true}, [name]).execute!
              else
                ui.fatal "Create of new stack #{ui.color(name, :bold)}: #{ui.color('FAILED', :red, :bold)}"
                raise
              end
            else
              ui.warn 'Stack state polling has been disabled.'
              ui.info "Stack creation initialized for #{ui.color(name, :green)}"
            end
          end

        end

      end

    end
  end
end
