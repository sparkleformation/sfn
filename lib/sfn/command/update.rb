require 'sfn'

module Sfn
  class Command
    # Update command
    class Update < Command

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

        stack_info = "#{ui.color('Name:', :bold)} #{name}"

        if(config[:file])
          file = load_template_file
          stack_info << " #{ui.color('Path:', :bold)} #{config[:file]}"
          nested_stacks = file.delete('sfn_nested_stack')
        end

        if(nested_stacks)

          unpack_nesting(name, file, :update)

        else
          stack = provider.connection.stacks.get(name)

          if(stack)
            ui.info "#{ui.color('SparkleFormation:', :bold)} #{ui.color('update', :green)}"

            unless(file)
              if(config[:template])
                file = config[:template]
                c_setter = lamda do |c_stack|
                  compile_params = c_stack.outputs.all.detect do |output|
                    output.key == 'CompileState'
                  end
                  if(compile_params)
                    compile_params = MultiJson.load(compile_params.value)
                    c_current = config[:compile_paramaters].fetch(s_name.join('_'), Smash.new)
                    config[:compile_parameters][s_name.join('_')] = compile_params.merge(c_current)
                  end
                end
                s_name = ['root']
                c_setter.call(stack)
                stack.resources.all do |s_resource|
                  if(s_resource.type == 'AWS::CloudFormation::Stack')
                    c_setter.call(s_resource.expand)
                  end
                end
                stack_info << " #{ui.color('(template provided)', :green)}"
              else
                stack_info << " #{ui.color('(no template update)', :yellow)}"
              end
            end
            ui.info "  -> #{stack_info}"


            if(file)
              stack.template = translate_template(file)
              apply_stacks!(stack)
              populate_parameters!(file, stack.parameters)
              stack.parameters = config[:parameters]
              stack.template = Sfn::Utils::StackParameterScrubber.scrub!(stack.template)
            else
              apply_stacks!(stack)
              populate_parameters!(stack.template, stack.parameters)
              stack.parameters = config[:parameters]
            end

            begin
              stack.save
            rescue Miasma::Error::ApiError::RequestError => e
              if(e.message.downcase.include?('no updates'))
                ui.warn "No updates detected for stack (#{stack.name})"
              else
                raise
              end
            end

            if(config[:poll])
              poll_stack(stack.name)
              if(stack.reload.state == :update_complete)
                ui.info "Stack update complete: #{ui.color('SUCCESS', :green)}"
                namespace.const_get(:Describe).new({:outputs => true}, [name]).execute!
              else
                ui.fatal "Update of stack #{ui.color(name, :bold)}: #{ui.color('FAILED', :red, :bold)}"
                ui.info ""
                namespace.const_get(:Inspect).new({:instance_failure => true}, [name]).execute!
                raise
              end
            else
              ui.warn 'Stack state polling has been disabled.'
              ui.info "Stack update initialized for #{ui.color(name, :green)}"
            end
          else
            ui.fatal "Failed to locate requested stack: #{ui.color(name, :red, :bold)}"
            raise
          end

        end
      end

    end
  end
end
