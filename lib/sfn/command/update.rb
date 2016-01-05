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
        name_required!
        name = name_args.first

        stack_info = "#{ui.color('Name:', :bold)} #{name}"
        begin
          stack = provider.connection.stacks.get(name)
        rescue Miasma::Error::ApiError::RequestError
          stack = nil
        end

        config[:compile_parameters] ||= Smash.new

        if(config[:file])
          s_name = [name]

          c_setter = lambda do |c_stack|
            compile_params = c_stack.outputs.detect do |output|
              output.key == 'CompileState'
            end
            if(compile_params)
              compile_params = MultiJson.load(compile_params.value)
              c_current = config[:compile_parameters].fetch(s_name.join('_'), Smash.new)
              config[:compile_parameters][s_name.join('_')] = compile_params.merge(c_current)
            end
            c_stack.nested_stacks(false).each do |n_stack|
              s_name.push(n_stack.name)
              c_setter.call(n_stack)
              s_name.pop
            end
          end

          if(stack)
            c_setter.call(stack)
          end

          file = load_template_file(:stack => stack)
          stack_info << " #{ui.color('Path:', :bold)} #{config[:file]}"
          nested_stacks = file.delete('sfn_nested_stack')
        end

        if(nested_stacks)
          unpack_nesting(name, file, :update)
        else
          unless(stack)
            ui.fatal "Failed to locate requested stack: #{ui.color(name, :red, :bold)}"
            raise "Failed to locate stack: #{name}"
          end

          ui.info "#{ui.color('SparkleFormation:', :bold)} #{ui.color('update', :green)}"

          unless(file)
            if(config[:template])
              file = config[:template]
              stack_info << " #{ui.color('(template provided)', :green)}"
            else
              stack_info << " #{ui.color('(no template update)', :yellow)}"
            end
          end
          ui.info "  -> #{stack_info}"

          if(file)
            if(config[:print_only])
              ui.puts _format_json(translate_template(file))
              return
            end

            original_template = stack.template
            original_parameters = stack.parameters

            stack.template = translate_template(file)
            apply_stacks!(stack)

            populate_parameters!(file, :current_parameters => stack.parameters)
            update_template = stack.template

            if(config[:plan])
              stack.template = original_template
              stack.parameters = original_parameters
              plan = build_planner(stack)
              if(plan)
                result = plan.generate_plan(file, config_root_parameters)
                display_plan_information(result)
              end
            end

            stack.parameters = config_root_parameters
            stack.template = scrub_template(update_template)
          else
            apply_stacks!(stack)

            original_parameters = stack.parameters
            populate_parameters!(stack.template, :current_parameters => stack.parameters)

            if(config[:plan])
              stack.parameters = original_parameters
              plan = Planner::Aws.new(ui, config, arguments, stack)
              if(plan)
                result = plan.generate_plan(stack.template, config_root_parameters)
                display_plan_information(result)
              end
            end
            stack.parameters = config_root_parameters
          end

          begin
            api_action!(:api_stack => stack) do
              stack.save
              if(config[:poll])
                poll_stack(stack.name)
                if(stack.reload.state == :update_complete)
                  ui.info "Stack update complete: #{ui.color('SUCCESS', :green)}"
                  stack.resources.reload
                  stack.outputs.reload
                  namespace.const_get(:Describe).new({:outputs => true}, [name]).execute!
                else
                  ui.fatal "Update of stack #{ui.color(name, :bold)}: #{ui.color('FAILED', :red, :bold)}"
                  raise
                end
              else
                ui.warn 'Stack state polling has been disabled.'
                ui.info "Stack update initialized for #{ui.color(name, :green)}"
              end
            end
          rescue Miasma::Error::ApiError::RequestError => e
            if(e.message.downcase.include?('no updates'))
              ui.warn "No updates detected for stack (#{stack.name})"
            else
              raise
            end
          end

        end
      end

      def build_planner(stack)
        klass_name = stack.api.class.to_s.split('::').last
        klass = Planner.const_get(klass_name)
        if(klass)
          klass.new(ui, config, arguments, stack)
        else
          warn "Failed to build planner for current provider. No provider implemented. (`#{klass_name}`)"
          nil
        end
      end

      def display_plan_information(result)
        ui.info ui.color('Pre-update resource planning report:', :bold)
        unless(print_plan_result(result))
          ui.info 'No resources life cycle changes detected in this update!'
        end
        ui.confirm 'Apply this stack update?'
      end


      def print_plan_result(info, names=[])
        said_any_things = false
        unless(info[:stacks].empty?)
          info[:stacks].each do |s_name, s_info|
            said_things = print_plan_result(s_info, [*names, s_name].compact)
          end
        end
        unless(names.flatten.compact.empty?)
          said_things = false
          ui.puts
          ui.puts "  #{ui.color('Update plan for:', :bold)} #{ui.color(names.join(' > '), :blue)}"
          unless(info[:unknown].empty?)
            ui.puts "    #{ui.color('!!! Unknown update effect:', :red, :bold)}"
            print_plan_items(info, :unknown, :red)
            ui.puts
            said_any_things = said_things = true
          end
          unless(info[:unavailable].empty?)
            ui.puts "    #{ui.color('Update request not allowed:', :red, :bold)}"
            print_plan_items(info, :unavailable, :red)
            ui.puts
            said_any_things = said_things = true
          end
          unless(info[:replace].empty?)
            ui.puts "    #{ui.color('Resources to be replaced:', :red, :bold)}"
            print_plan_items(info, :replace, :red)
            ui.puts
            said_any_things = said_things = true
          end
          unless(info[:interrupt].empty?)
            ui.puts "    #{ui.color('Resources to be interrupted:', :yellow, :bold)}"
            print_plan_items(info, :interrupt, :yellow)
            ui.puts
            said_any_things = said_things = true
          end
          unless(info[:removed].empty?)
            ui.puts "    #{ui.color('Resources to be removed:', :red, :bold)}"
            print_plan_items(info, :removed, :red)
            ui.puts
            said_any_things = said_things = true
          end
          unless(info[:added].empty?)
            ui.puts "    #{ui.color('Resources to be added:', :green, :bold)}"
            print_plan_items(info, :added, :green)
            ui.puts
            said_any_things = said_things = true
          end
          unless(said_things)
            ui.puts "    #{ui.color('No resource lifecycle changes detected!', :green)}"
            ui.puts
          end
        end
        said_any_things
      end

      # Print planning items
      #
      # @param info [Hash] plan
      # @param key [Symbol] key of items
      # @param color [Symbol] color to flag
      def print_plan_items(info, key, color)
        max_name = info[key].keys.map(&:size).max
        max_type = info[key].values.map{|i|i[:type]}.map(&:size).max
        info[key].each do |name, val|
          ui.print ' ' * 6
          ui.print ui.color("[#{val[:type]}]", color)
          ui.print ' ' * (max_type - val[:type].size)
          ui.print ' ' * 4
          ui.print ui.color(name, :bold)
          unless(val[:properties].nil? || val[:properties].empty?)
            ui.print ' ' * (max_name - name.size)
            ui.print ' ' * 4
            ui.print "Reason: Updated properties: `#{val[:properties].join('`, `')}`"
          end
          ui.puts
        end
      end

      # Scrub sparkle/sfn customizations from the stack resource data
      #
      # @param template [Hash]
      # @return [Hash]
      def scrub_template(template)
        template = Sfn::Utils::StackParameterScrubber.scrub!(template)
        (template['Resources'] || {}).each do |r_name, r_content|
          if(valid_stack_types.include?(r_content['Type']))
            (r_content['Properties'] || {}).delete('Stack')
          end
        end
        template
      end

    end
  end
end
