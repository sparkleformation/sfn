require 'sfn'
require 'sparkle_formation'

module Sfn
  module CommandModule
    # Stack handling helper methods
    module Stack

      module InstanceMethods

        # maximum number of attempts to get valid parameter value
        MAX_PARAMETER_ATTEMPTS = 5
        # Template parameter locations
        TEMPLATE_PARAMETER_LOCATIONS = ['Parameters', 'parameters']
        # Template parameter default value locations
        TEMPLATE_PARAMETER_DEFAULTS = ['Default', 'defaultValue', 'default']
        # Template parameter no echo locations
        TEMPLATE_PARAMETER_NOECHO = ['NoEcho']
        # Template parameter no echo custom
        TEMPLATE_PARAMETER_SFN_NOECHO = ['Quiet', 'quiet']

        # Apply any defined remote stacks
        #
        # @param stack [Miasma::Models::Orchestration::Stack]
        # @return [Miasma::Models::Orchestration::Stack]
        def apply_stacks!(stack)
          remote_stacks = [config[:apply_stack]].flatten.compact
          remote_stacks.each do |stack_name|
            stack_info = stack_name.split('__')
            stack_info.unshift(nil) if stack_info.size == 1
            stack_location, stack_name = stack_info
            remote_stack = provider_for(stack_location).stack(stack_name)
            if(remote_stack)
              apply_nested_stacks!(remote_stack, stack)
              mappings = generate_custom_apply_mappings(remote_stack)
              execute_apply_stack(remote_stack, stack, mappings)
            else
              ui.error "Failed to apply requested stack. Unable to locate. (#{stack_name})"
              raise "Failed to locate stack: #{stack}"
            end
          end
          stack
        end

        # Detect nested stacks and apply
        #
        # @param remote_stack [Miasma::Models::Orchestration::Stack] stack to inspect for nested stacks
        # @param stack [Miasma::Models::Orchestration::Stack] current stack
        # @return [Miasma::Models::Orchestration::Stack]
        def apply_nested_stacks!(remote_stack, stack)
          remote_stack.resources.all.each do |resource|
            if(valid_stack_types.include?(resource.type))
              nested_stack = resource.expand
              apply_nested_stacks!(nested_stack, stack)
              mappings = generate_custom_apply_mappings(nested_stack)
              execute_apply_stack(nested_stack, stack, mappings)
            end
          end
          stack
        end

        # Build apply mappings valid for given provider stack
        #
        # @param provider_stack [Miasma::Models::Orchestration::Stack] stack providing outputs
        # @return [Hash] output to parameter mapping
        def generate_custom_apply_mappings(provider_stack)
          if(config[:apply_mapping])
            valid_keys = config[:apply_mapping].keys.find_all do |a_key|
              a_key = a_key.to_s
              key_parts = a_key.split('__')
              case key_parts.size
              when 3
                provider_stack.api.data[:location] == key_parts[0] &&
                  provider_stack.name == key_parts[1]
              when 2
                provider_stack.name == key_parts[1]
              when 1
                true
              else
                raise ArgumentError "Invalid name format for apply stack mapping (`#{a_key}`)"
              end
            end
            to_remove = valid_keys.find_all do |key|
              valid_keys.any?{|v_key| v_key.match(/__#{Regexp.escape(key)}$/)}
            end
            valid_keys -= to_remove
            Hash[
              valid_keys.map do |a_key|
                cut_key = a_key.split('__').last
                [cut_key, config[:apply_mapping][a_key]]
              end
            ]
          end
        end

        # Apply provider stack outputs to receiver stack parameters
        #
        # @param provider_stack [Miasma::Models::Orchestration::Stack] stack providing outputs
        # @param receiver_stack [Miasma::Models::Orchestration::Stack] stack receiving outputs for parameters
        # @return [TrueClass]
        def execute_apply_stack(provider_stack, receiver_stack, mappings)
          receiver_stack.apply_stack(provider_stack, :mapping => mappings)
          true
        end

        # Generate name prefix for config parameter based on location and
        # extract template parameters
        #
        # @param sparkle [SparkleFormation, Hash] template instance
        # @return [Array<Array<String>, Smash>] prefix value, parameters
        def prefix_parameters_setup(sparkle)
          if(sparkle.is_a?(SparkleFormation))
            parameter_prefix = sparkle.root? ? [] : (sparkle.root_path - [sparkle.root]).map do |s|
              Bogo::Utility.camel(s.name)
            end
            stack_parameters = sparkle.compile.parameters
            stack_parameters = stack_parameters.nil? ? Smash.new : stack_parameters._dump
          else
            parameter_prefix = []
            stack_parameters = TEMPLATE_PARAMETER_LOCATIONS.map do |loc_key|
              sparkle[loc_key]
            end.compact.first || Smash.new
          end
          [parameter_prefix, stack_parameters]
        end

        # Format config defined parameters to ensure expected layout
        def format_config_parameters!
          if(config.get(:parameter).is_a?(Array))
            config[:parameter] = Smash[
              *config.get(:parameter).map(&:to_a).flatten
            ]
          end
          if(config.get(:parameters))
            config.set(:parameters,
              config.get(:parameters).merge(config.fetch(:parameter, Smash.new))
            )
          else
            config.set(:parameters, config.fetch(:parameter, Smash.new))
          end
        end

        # Determine correct configuration parameter key
        #
        # @param parameter_prefix [Array<String>] nesting prefix names
        # @param parameter_name [String] parameter name
        # @return [Array<String>] [expected_template_key, configuration_used_key]
        def locate_config_parameter_key(parameter_prefix, parameter_name, root_name)
          check_name = parameter_name.downcase.tr('-_', '')
          check_prefix = parameter_prefix.map{|i| i.downcase.tr('-_', '') }
          key_match = config[:parameters].keys.detect do |cp_key|
            cp_key = cp_key.to_s.downcase.split('__').map{|i| i.tr('-_', '') }.join('__')
            non_root_matcher = (check_prefix + [check_name]).join('__')
            root_matcher = ([root_name] + check_prefix + [check_name]).join('__')
            cp_key == non_root_matcher ||
              cp_key == root_matcher
          end
          actual_key = (parameter_prefix + [parameter_name]).compact.join('__')
          if(key_match)
            ui.debug "Remapping configuration runtime parameter `#{key_match}` -> `#{actual_key}`"
            config[:parameters][actual_key] = config[:parameters].delete(key_match)
          end
          actual_key
        end

        # Populate stack parameter value via user interaction
        #
        # @param sparkle [SparkleFormation, Hash] template
        # @param ns_key [String] configuration parameter key name
        # @param param_name [String] template parameter name
        # @param param_value [Hash] template parameter value
        # @param current_parameters [Hash] currently set stack parameters
        # @param param_banner [TrueClass, FalseClass] parameter banner has been printed
        # @return [TrueClass, FalseClass] parameter banner has been printed
        def set_parameter(sparkle, ns_key, param_name, param_value, current_parameters, param_banner)
          valid = false
          attempt = 0
          if(!valid && !param_banner)
            if(sparkle.is_a?(SparkleFormation))
              ui.info "#{ui.color('Stack runtime parameters:', :bold)} - template: #{ui.color(sparkle.root_path.map(&:name).map(&:to_s).join(' > '), :green, :bold)}"
            else
              ui.info ui.color('Stack runtime parameters:', :bold)
            end
            param_banner = true
          end
          until(valid)
            attempt += 1
            default = config[:parameters].fetch(
              ns_key, current_parameters.fetch(
                param_name, TEMPLATE_PARAMETER_DEFAULTS.map{|loc_key| param_value[loc_key]}.compact.first
              )
            )
            if(config[:interactive_parameters])
              no_echo = !!TEMPLATE_PARAMETER_NOECHO.detect{|loc_key|
                param_value[loc_key].to_s.downcase == 'true'
              }
              sfn_no_echo = TEMPLATE_PARAMETER_SFN_NOECHO.map do |loc_key|
                res = param_value.delete(loc_key).to_s.downcase
                res if !res.empty? && res != 'false'
              end.compact.first
              no_echo = sfn_no_echo if sfn_no_echo
              answer = ui.ask_question(
                "#{param_name.split(/([A-Z]+[^A-Z]*)/).find_all{|s|!s.empty?}.join(' ')}",
                :default => default,
                :hide_default => sfn_no_echo == 'all',
                :no_echo => !!no_echo
              )
            else
              answer = default
            end
            validation = validate_parameter(answer, param_value)
            if(validation == true)
              config[:parameters][ns_key] = answer
              valid = true
            else
              validation.each do |validation_error|
                ui.error validation_error.last
              end
            end
            if(attempt > MAX_PARAMETER_ATTEMPTS)
              ui.fatal 'Failed to receive allowed parameter!'
              exit 1
            end
          end
          param_banner
        end

        # Prompt for parameter values and store result
        #
        # @param sparkle [SparkleFormation, Hash]
        # @param opts [Hash]
        # @option opts [Hash] :current_parameters current stack parameter values
        # @option opts [Miasma::Models::Orchestration::Stack] :stack existing stack
        # @return [Hash]
        def populate_parameters!(sparkle, opts={})
          current_parameters = opts.fetch(:current_parameters, {})
          current_stack = opts[:stack]
          parameter_prefix, stack_parameters = prefix_parameters_setup(sparkle)
          unless(stack_parameters.empty?)
            format_config_parameters!
            param_banner = false
            stack_parameters.each do |param_name, param_value|
              ns_key = locate_config_parameter_key(parameter_prefix, param_name, sparkle.root.name)
              # When parameter is a hash type, it is being set via
              # intrinsic function and we don't modify
              if(function_set_parameter?(current_parameters[param_name]))
                if(!config[:parameters][ns_key].nil?)
                  ui.warn "Overriding mapped parameter value with explicit assignment `#{ns_key}`!"
                else
                  if(current_stack)
                    enable_set = validate_stack_parameter(current_stack, param_name, ns_key, current_parameters[param_name])
                  else
                    enable_set = true
                  end
                end
                if(enable_set)
                  # NOTE: direct set dumps the stack (nfi). Smash will
                  # auto dup it, and works, so yay i guess.
                  config[:parameters][ns_key] = current_parameters[param_name].is_a?(Hash) ?
                    Smash.new(current_parameters[param_name]) :
                    current_parameters[param_name].dup
                  valid = true
                end
              else
                if(current_stack && current_stack.data[:parent_stack])
                  use_expected = validate_stack_parameter(current_stack, param_name, ns_key, current_parameters[param_name])
                  unless(use_expected)
                    current_parameters[param_name] = current_stack.parameters[param_name]
                  end
                end
              end
              unless(valid)
                param_banner = set_parameter(sparkle, ns_key, param_name, param_value, current_parameters, param_banner)
              end
            end
          end
          Smash[
            config.fetch(:parameters, {}).map do |k,v|
              strip_key = parameter_prefix ? k.sub(/#{parameter_prefix.join('__')}_{2}?/, '') : k
              unless(strip_key.include?('__'))
                [strip_key, v]
              end
            end.compact
          ]
        end

        # Determine if parameter was set via intrinsic function
        #
        # @param val [Object]
        # @return [TrueClass, FalseClass]
        def function_set_parameter?(val)
          val.is_a?(Hash)
        end

        # @return [Hash] parameters for root stack create/update
        def config_root_parameters
          Hash[
            config.fetch(:parameters, {}).find_all do |k,v|
              !k.include?('__')
            end
          ]
        end

        # Validate stack parameter is properly set via stack resource
        # from parent stack. If not properly set, prompt user for
        # expected behavior. This accounts for states encountered when
        # a nested stack's parameters are adjusted directly but the
        # resource sets value via intrinsic function.
        #
        # @param c_stack [Miasma::Models::Orchestration::Stack] current stack
        # @param p_key [String] stack parameter key
        # @param p_ns_key [String] namespaced stack parameter key
        # @param c_value [Hash] currently set value (via intrinsic function)
        # @return [TrueClass, FalseClass] value is validated
        def validate_stack_parameter(c_stack, p_key, p_ns_key, c_value)
          stack_value = c_stack.parameters[p_key]
          p_stack = c_stack.data[:parent_stack]
          unless(config[:parameter_validation] == 'none')
            if(c_value.is_a?(Hash))
              case c_value.keys.first
              when 'Ref'
                current_value = p_stack.parameters[c_value.values.first]
              when 'Fn::Att'
                resource_name, output_name = c_value.values.first.split('.', 2)
                ref_stack = p_stack.nested_stacks.detect{|i| i.data[:logical_id] == resource_name}
                if(ref_stack)
                  output = ref_stack.outputs.detect do |o|
                    o.key == output_name
                  end
                  if(output)
                    current_value = output.value
                  end
                end
              end
            else
              current_value = c_value
            end
            if(current_value && current_value.to_s != stack_value.to_s)
              if(config[:parameter_validation] == 'default')
                ui.warn 'Nested stack has been altered directly! This update may cause unexpected modifications!'
                ui.warn "Stack name: #{c_stack.name}. Parameter: #{p_key}. Current value: #{stack_value}. Expected value: #{current_value} (via: #{c_value.inspect})"
                answer = ui.ask_question("Use current value or expected value for #{p_key} [current/expected]?", :valid => ['current', 'expected'])
              else
                answer = config[:parameter_validation]
              end
              answer == 'expected'
            else
              true
            end
          else
            true
          end
        end

      end

      module ClassMethods
      end

      # Load methods into class and define options
      #
      # @param klass [Class]
      def self.included(klass)
        klass.class_eval do
          extend Sfn::CommandModule::Stack::ClassMethods
          include Sfn::CommandModule::Stack::InstanceMethods
          include Utils::StackParameterValidator
        end
      end

    end
  end
end
