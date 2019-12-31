require "sfn"

module Sfn
  class Command
    # Update command
    class Update < Command
      include Sfn::CommandModule::Base
      include Sfn::CommandModule::Template
      include Sfn::CommandModule::Stack
      include Sfn::CommandModule::Planning

      # Run the stack update command
      def execute!
        name_required!
        name = name_args.first

        stack_info = "#{ui.color("Name:", :bold)} #{name}"
        begin
          stack = provider.stacks.get(name)
        rescue Miasma::Error::ApiError::RequestError => error
          ui.error error.message unless error.response.code == 404
          stack = nil
        end

        config[:compile_parameters] ||= Smash.new

        if config[:file]
          s_name = [name]

          c_setter = lambda do |c_stack|
            if c_stack.outputs
              compile_params = c_stack.outputs.detect do |output|
                output.key == "CompileState"
              end
            end
            if compile_params
              compile_params = MultiJson.load(compile_params.value)
              c_current = config[:compile_parameters].fetch(s_name.join("__"), Smash.new)
              config[:compile_parameters][s_name.join("__")] = compile_params.merge(c_current)
            end
            c_stack.nested_stacks(false).each do |n_stack|
              s_name.push(n_stack.data.fetch(:logical_id, n_stack.name))
              c_setter.call(n_stack)
              s_name.pop
            end
          end

          if stack
            c_setter.call(stack)
          end

          ui.debug "Compile parameters - #{config[:compile_parameters]}"
          file = load_template_file(:stack => stack)
          stack_info << " #{ui.color("Path:", :bold)} #{config[:file]}"
        else
          file = stack.template.dup if config[:plan]
        end

        unless stack
          ui.fatal "Failed to locate requested stack: #{ui.color(name, :red, :bold)}"
          raise "Failed to locate stack: #{name}"
        end

        unless config[:print_only]
          ui.info "#{ui.color("SparkleFormation:", :bold)} #{ui.color("update", :green)}"
        end

        unless file
          if config[:template]
            file = config[:template]
            stack_info << " #{ui.color("(template provided)", :green)}"
          else
            stack_info << " #{ui.color("(no template update)", :yellow)}"
          end
        end
        unless config[:print_only]
          ui.info "  -> #{stack_info}"
        end
        if file
          if config[:print_only]
            ui.puts format_json(parameter_scrub!(template_content(file)))
            return
          end

          original_template = stack.template
          original_parameters = stack.parameters

          apply_stacks!(stack)

          populate_parameters!(file, :current_parameters => stack.root_parameters)
          update_template = stack.template

          if config[:plan]
            begin
              stack.template = original_template
              stack.parameters = original_parameters
              plan = build_planner(stack)
              if plan
                result = plan.generate_plan(
                  file.respond_to?(:dump) ? file.dump : file,
                  config_root_parameters
                )
                display_plan_information(result)
              end
            rescue => e
              unless e.message.include?("Confirmation declined")
                ui.error "Unexpected error when generating plan information: #{e.class} - #{e}"
                ui.debug "#{e.class}: #{e}\n#{e.backtrace.join("\n")}"
                ui.confirm "Continue with stack update?" unless config[:plan_only]
              else
                raise
              end
            end
            if config[:plan_only]
              ui.info "Plan only mode requested. Exiting."
              return
            end
          end
          stack.parameters = config_root_parameters

          if config[:upload_root_template]
            upload_result = store_template(name, file, Smash.new)
            stack.template_url = upload_result[:url]
          else
            stack.template = parameter_scrub!(template_content(file, :scrub))
          end
        else
          apply_stacks!(stack)
          original_parameters = stack.parameters
          populate_parameters!(stack.template, :current_parameters => stack.root_parameters)
          stack.parameters = config_root_parameters
        end

        # Set options defined within config into stack instance for update request
        if config[:merge_api_options]
          config.fetch(:options, Smash.new).each_pair do |key, value|
            if stack.respond_to?("#{key}=")
              stack.send("#{key}=", value)
            end
          end
        end

        begin
          api_action!(:api_stack => stack) do
            stack.save
            if config[:poll]
              poll_stack(stack.name)
              if stack.reload.state == :update_complete
                ui.info "Stack update complete: #{ui.color("SUCCESS", :green)}"
                namespace.const_get(:Describe).new({:outputs => true}, [name]).execute!
              else
                ui.fatal "Update of stack #{ui.color(name, :bold)}: #{ui.color("FAILED", :red, :bold)}"
                raise "Stack did not reach a successful update completion state."
              end
            else
              ui.warn "Stack state polling has been disabled."
              ui.info "Stack update initialized for #{ui.color(name, :green)}"
            end
          end
        rescue Miasma::Error::ApiError::RequestError => e
          if e.message.downcase.include?("no updates")
            ui.warn "No updates detected for stack (#{stack.name})"
          else
            raise
          end
        end
      end
    end
  end
end
