require "sfn"

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

        stack_info = "#{ui.color("Name:", :bold)} #{name}"
        begin
          stack = provider.stacks.get(name)
        rescue Miasma::Error::ApiError::RequestError
          stack = provider.stacks.build(name: name)
        end

        return display_plan_lists(stack) if config[:list]

        if config[:plan_name]
          # ensure custom attribute is dirty so we can modify
          stack.custom = stack.custom.dup
          stack.custom[:plan_name] = config[:plan_name]
        end

        use_existing = false

        unless config[:print_only]
          ui.info "#{ui.color("SparkleFormation:", :bold)} #{ui.color("plan", :green)}"
          if stack && stack.plan
            ui.warn "Found existing plan for this stack"
            begin
              if config[:load_existing]
                raise Bogo::Ui::ConfirmationDeclined
              end
              if config[:load_existing].nil?
                ui.confirm "Destroy existing plan"
              end
              ui.info "Destroying existing plan to generate new plan"
              stack.plan.destroy
            rescue Bogo::Ui::ConfirmationDeclined
              ui.info "Loading existing stack plan for #{ui.color(stack.name, :bold)}..."
              use_existing = true
            end
          end
        end

        unless use_existing
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

            if stack && stack.persisted?
              c_setter.call(stack)
            end

            ui.debug "Compile parameters - #{config[:compile_parameters]}"
            file = load_template_file(:stack => stack)
            stack_info << " #{ui.color("Path:", :bold)} #{config[:file]}"
          else
            file = stack.template.dup
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
          if config[:merge_api_options]
            config.fetch(:options, Smash.new).each_pair do |key, value|
              if stack.respond_to?("#{key}=")
                stack.send("#{key}=", value)
              end
            end
          end

          ui.info "  -> Generating plan information..."
        else
          ui.info "  -> Loading plan information..."
        end

        plan = stack.plan || stack.plan_generate
        namespace.const_get(:Realize).
          new(config, [name]).execute!
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
        n_width = "Plan Name".length
        i_width = "Plan ID".length
        s_width = "Plan State".length
        c_width = "Created".length
        plan_info = plans.map do |plan|
          plan_id = plan.id.to_s.split("/").last
          n_width = plan.name.to_s.length if plan.name.to_s.length > n_width
          i_width = plan_id.to_s.length if plan_id.length > i_width
          s_width = plan.state.to_s.length if plan.state.to_s.length > s_width
          c_width = plan.created_at.to_s.length if plan.created_at.to_s.length > c_width
          [plan.name, plan_id, plan.state, plan.created_at]
        end
        table = ui.table(self) do
          table(:border => false) do
            row(:header => true) do
              column "Plan Name", :width => n_width + 5
              column "Plan ID", :width => i_width + 5
              column "Plan State", :width => s_width + 5
              column "Created", :width => c_width + 5
            end
            plan_info.sort_by(&:first).each do |plan|
              row do
                plan.each do |item|
                  column item
                end
              end
            end
          end
        end.display
      end
    end
  end
end
