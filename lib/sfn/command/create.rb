require "sparkle_formation"
require "sfn"

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

        # NOTE: Always disable plans on create
        config[:plan] = false

        if config[:template]
          file = config[:template]
        else
          file = load_template_file
        end

        unless config[:print_only]
          ui.info "#{ui.color("SparkleFormation:", :bold)} #{ui.color("create", :green)}"
        end

        stack_info = "#{ui.color("Name:", :bold)} #{name}"
        if config[:path]
          stack_info << " #{ui.color("Path:", :bold)} #{config[:file]}"
        end

        if config[:print_only]
          ui.puts format_json(parameter_scrub!(template_content(file)))
          return
        else
          ui.info "  -> #{stack_info}"
        end

        stack = provider.connection.stacks.build(
          config.fetch(:options, Smash.new).dup.merge(
            :name => name,
            :template => template_content(file),
            :parameters => Smash.new,
            :tags => config.fetch(:tags, Smash.new),
          ) { |key, oldval, newval| oldval.respond_to?(:merge) ? oldval.merge(newval) : newval }
        )

        apply_stacks!(stack)
        populate_parameters!(file, :current_parameters => stack.parameters)

        stack.parameters = config_root_parameters

        if config[:upload_root_template]
          upload_result = store_template(name, file, Smash.new)
          stack.template_url = upload_result[:url]
        else
          stack.template = parameter_scrub!(template_content(file, :scrub))
        end

        api_action!(:api_stack => stack) do
          stack.save
          if config[:poll]
            poll_stack(stack.name)
            stack = provider.stack(name)

            if stack.reload.state == :create_complete
              ui.info "Stack create complete: #{ui.color("SUCCESS", :green)}"
              namespace.const_get(:Describe).new({:outputs => true}, [name]).execute!
            else
              ui.fatal "Create of new stack #{ui.color(name, :bold)}: #{ui.color("FAILED", :red, :bold)}"
              raise "Stack did not reach a successful completion state."
            end
          else
            ui.warn "Stack state polling has been disabled."
            ui.info "Stack creation initialized for #{ui.color(name, :green)}"
          end
        end
      end
    end
  end
end
