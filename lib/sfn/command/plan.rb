require 'sfn'

module Sfn
  class Command
    # Plan command
    class Plan < Command
      include Sfn::CommandModule::Base
      include Sfn::CommandModule::Planning
      include Sfn::CommandModule::Stack
      include Sfn::CommandModule::Template

      # Run the stack planning command
      def execute!
        name_required!
        name = name_args.first

        stack_info = "#{ui.color('Name:', :bold)} #{name}"
        begin
          stack = provider.stacks.get(name)
        rescue Miasma::Error::ApiError::RequestError
          stack = nil
        end

        return display_plan_lists(stack) if config[:list]

        config[:compile_parameters] ||= Smash.new

        if config[:file]
          s_name = [name]

          c_setter = lambda do |c_stack|
            if c_stack.outputs
              compile_params = c_stack.outputs.detect do |output|
                output.key == 'CompileState'
              end
            end
            if compile_params
              compile_params = MultiJson.load(compile_params.value)
              c_current = config[:compile_parameters].fetch(s_name.join('__'), Smash.new)
              config[:compile_parameters][s_name.join('__')] = compile_params.merge(c_current)
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
          stack_info << " #{ui.color('Path:', :bold)} #{config[:file]}"
        else
          file = stack.template.dup
        end

        unless config[:print_only]
          ui.info "#{ui.color('SparkleFormation:', :bold)} #{ui.color('plan', :green)}"
          if stack.plan
            ui.warn "Destroying stale plan..."
            stack.plan.destroy
          end
        end

        unless file
          if config[:template]
            file = config[:template]
            stack_info << " #{ui.color('(template provided)', :green)}"
          else
            stack_info << " #{ui.color('(no template update)', :yellow)}"
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

          original_parameters = stack.parameters

          apply_stacks!(stack)

          populate_parameters!(file, :current_parameters => stack.root_parameters)

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

        if config[:plan_name]
          stack.custom[:plan_name] = config[:plan_name]
        end

        ui.info "  -> Generating plan information..."

        plan = stack.plan || stack.plan_generate
        display_plan_information(plan)

        if config[:merge_api_options]
          config.fetch(:options, Smash.new).each_pair do |key, value|
            if stack.respond_to?("#{key}=")
              stack.send("#{key}=", value)
            end
          end
        end

        begin
          api_action!(:api_stack => stack) do
            stack.plan_execute
            if config[:poll]
              poll_stack(stack.name)
              if stack.reload.state == :update_complete || stack.reload.state == :create_complete
                ui.info "Stack plan apply complete: #{ui.color('SUCCESS', :green)}"
                namespace.const_get(:Describe).new({:outputs => true}, [name]).execute!
              else
                ui.fatal "Update of stack #{ui.color(name, :bold)}: #{ui.color('FAILED', :red, :bold)}"
                raise 'Stack did not reach a successful completion state.'
              end
            else
              ui.warn 'Stack state polling has been disabled.'
              ui.info "Stack plan apply initialized for #{ui.color(name, :green)}"
            end
          end
        rescue Miasma::Error::ApiError::RequestError => e
          if e.message.downcase.include?('no updates')
            ui.warn "No changes detected for stack (#{stack.name})"
          else
            raise
          end
        end
      end

      # Display plan list in table form
      #
      # @param [Miasma::Models::Orchestration::Stack]
      def display_plan_lists(stack)
        unless stack
          raise "Failed to locate requested stack `#{name_args.first}`"
        end
        plans = stack.plans.all
        if plans.empty?
          ui.warn "No plans found for stack `#{stack.name}`"
          return
        end
        ui.info "Plans for stack: #{ui.color(stack.name, :bold)}\n"
        n_width = i_width = s_width = 0
        plans.each do |plan|
          n_width = plan.name.to_s.length if plan.name.to_s.length > n_width
          i_width = plan.id.to_s.length if plan.id.to_s.length > i_width
          s_width = plan.state.to_s.length if plan.state.to_s.length > s_width
        end
        plans.each do |plan|
          table = ui.table(self) do
            table(:border => false) do
              row(:header => true) do
                column "Plan Name", :width => n_width + 5
                column "Plan ID", :width => i_width + 5
                column "Plan State", :width => s_width + 5
              end
              plans.sort_by(&:name).each do |plan|
                row do
                  column plan.name
                  column plan.id
                  column plan.state
                end
              end
            end
          end
        end
      end
    end
  end
end
