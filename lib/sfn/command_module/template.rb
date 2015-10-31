require 'sfn'
require 'sparkle_formation'

require 'pathname'

module Sfn
  module CommandModule
    # Template handling helper methods
    module Template

      # cloudformation directories that should be ignored
      TEMPLATE_IGNORE_DIRECTORIES = %w(components dynamics registry)
      # maximum number of attempts to get valid parameter value
      MAX_PARAMETER_ATTEMPTS = 5

      module InstanceMethods

        # Request compile time parameter value
        #
        # @param p_name [String, Symbol] name of parameter
        # @param p_config [Hash] parameter meta information
        # @param cur_val [Object, NilClass] current value assigned to parameter
        # @param nested [TrueClass, FalseClass] template is nested
        # @option p_config [String, Symbol] :type
        # @option p_config [String, Symbol] :default
        # @option p_config [String, Symbol] :description
        # @option p_config [String, Symbol] :multiple
        # @return [Object]
        def request_compile_parameter(p_name, p_config, cur_val, nested=false)
          result = nil
          attempts = 0
          unless(cur_val || p_config[:default].nil?)
            cur_val = p_config[:default]
          end
          if(cur_val.is_a?(Array))
            cur_val = cur_val.map(&:to_s).join(',')
          end
          until(result && (!result.respond_to?(:empty?) || !result.empty?))
            attempts += 1
            if(config[:interactive_parameters] && (!nested || !p_config.key?(:prompt_when_nested) || p_config[:prompt_when_nested] == true))
              result = ui.ask_question(
                p_name.to_s.split('_').map(&:capitalize).join,
                :default => cur_val.to_s.empty? ? nil : cur_val.to_s
              )
            else
              result = cur_val.to_s
            end
            case p_config.fetch(:type, 'string').to_s.downcase.to_sym
            when :string
              if(p_config[:multiple])
                result = result.split(',').map(&:strip)
              end
            when :number
              if(p_config[:multiple])
                result = result.split(',').map(&:strip)
                new_result = result.map do |item|
                  new_item = item.to_i
                  new_item if new_item.to_s == item
                end
                result = new_result.size == result.size ? new_result : []
              else
                new_result = result.to_i
                result = new_result.to_s == result ? new_result : nil
              end
            else
              raise ArgumentError.new "Unknown compile time parameter type provided: `#{p_config[:type].inspect}` (Parameter: #{p_name})"
            end
            if(result.nil? || (result.respond_to?(:empty?) && result.empty?))
              if(attempts > MAX_PARAMETER_ATTEMPTS)
                ui.fatal 'Failed to receive allowed parameter!'
                exit 1
              else
                ui.error "Invalid value provided for parameter. Must be type: `#{p_config[:type].to_s.capitalize}`"
              end
            end
          end
          result
        end

        # @return [Array<SparkleFormation::SparklePack>]
        def sparkle_packs
          memoize(:sparkle_packs) do
            config.fetch(:sparkle_pack, []).map do |sparkle_name|
              SparkleFormation::Sparkle.new(:name => sparkle_name)
            end
          end
        end

        # @return [SparkleFormation::SparkleCollection]
        def sparkle_collection
          memoize(:sparkle_collection) do
            collection = SparkleFormation::SparkleCollection.new
            begin
              if(config[:base_directory])
                root_pack = SparkleFormation::SparklePack.new(:root => config[:base_directory])
              else
                root_pack = SparkleFormation::SparklePack.new
              end
              collection.set_root(root_pack)
            rescue Errno::ENOENT
              ui.warn 'No local SparkleFormation files detected'
            end
            sparkle_packs.each do |pack|
              collection.add_sparkle(pack)
            end
            collection
          end
        end

        # Load the template file
        #
        # @param args [Symbol] options (:allow_missing)
        # @return [Hash] loaded template
        def load_template_file(*args)
          c_stack = (args.detect{|i| i.is_a?(Hash)} || {})[:stack]
          unless(config[:template])
            set_paths_and_discover_file!
            unless(config[:file])
              unless(args.include?(:allow_missing))
                ui.fatal "Invalid formation file path provided: #{config[:file]}"
                raise IOError.new "Failed to locate file: #{config[:file]}"
              end
            end
          end
          if(config[:template])
            config[:template]
          elsif(config[:file])
            if(config[:processing])
              compile_state = config.fetch(:compile_parameters, Smash.new)
              sf = SparkleFormation.compile(config[:file], :sparkle)
              if(name_args.first)
                sf.name = name_args.first
              end
              sf.compile_time_parameter_setter do |formation|
                f_name = formation.root_path.map(&:name).map(&:to_s)
                pathed_name = f_name.join(' > ')
                f_name = f_name.join('_')
                current_state = compile_state.fetch(f_name, Smash.new)
                if(formation.compile_state)
                  current_state = current_state.merge(formation.compile_state)
                end
                ui.info "#{ui.color('Compile time parameters:', :bold)} - template: #{ui.color(pathed_name, :green, :bold)}" unless config[:print_only]
                formation.parameters.each do |k,v|
                  current_state[k] = request_compile_parameter(k, v, current_state[k], !!formation.parent)
                end
                formation.compile_state = current_state
              end
              sparkle_packs.each do |pack|
                sf.sparkle.add_sparkle(pack)
              end
              custom_stack_types.each do |s_type|
                unless(sf.stack_resource_types.include?(s_type))
                  sf.stack_resource_types.push(s_type)
                end
              end
              if(sf.nested? && !sf.isolated_nests?)
                raise TypeError.new('Template does not contain isolated stack nesting! Sfn does not support mixed mixed resources within root stack!')
              end
              run_callbacks_for(:template, :stack_name => arguments.first, :sparkle_stack => sf)
              if(sf.nested? && config[:apply_nesting])
                if(config[:apply_nesting] == true)
                  config[:apply_nesting] = :deep
                end
                case config[:apply_nesting].to_sym
                when :deep
                  process_nested_stack_deep(sf, c_stack)
                when :shallow
                  process_nested_stack_shallow(sf, c_stack)
                else
                  raise ArgumentError.new "Unknown nesting style requested: #{config[:apply_nesting].inspect}!"
                end
              else
                sf.dump.merge('sfn_nested_stack' => !!sf.nested?)
              end
            else
              template = _from_json(File.read(config[:file]))
              run_callbacks_for(:template, :stack_name => arguments.first, :hash_stack => template)
              template
            end
          else
            raise ArgumentError.new 'Failed to locate template for processing!'
          end
        end

        # Processes template using the original shallow workflow
        #
        # @param sf [SparkleFormation] stack formation
        # @param c_stack [Miasma::Models::Orchestration::Stack] existing stack
        # @return [Hash] dumped stack
        def process_nested_stack_shallow(sf, c_stack=nil)
          sf.apply_nesting(:shallow) do |stack_name, stack, resource|
            run_callbacks_for(:template, :stack_name => stack_name, :sparkle_stack => stack)
            stack_definition = stack.compile.dump!
            bucket = provider.connection.api_for(:storage).buckets.get(
              config[:nesting_bucket]
            )
            if(config[:print_only])
              template_url = "http://example.com/bucket/#{name_args.first}_#{stack_name}.json"
            else
              resource.properties.delete!(:stack) unless config[:plan]
              unless(bucket)
                raise "Failed to locate configured bucket for stack template storage (#{bucket})!"
              end
              file = bucket.files.build
              file.name = "#{name_args.first}_#{stack_name}.json"
              file.content_type = 'text/json'
              file.body = MultiJson.dump(Sfn::Utils::StackParameterScrubber.scrub!(stack_definition))
              file.save
              url = URI.parse(file.url)
              template_url = "#{url.scheme}://#{url.host}#{url.path}"
            end
            resource.properties.set!('TemplateURL', template_url)
          end
        end

        # Processes template using new deep workflow
        #
        # @param sf [SparkleFormation] stack
        # @param c_stack [Miasma::Models::Orchestration::Stack] existing stack
        # @return [Hash] dumped stack
        def process_nested_stack_deep(sf, c_stack=nil)
          sf.apply_nesting(:deep) do |stack_name, stack, resource|
            run_callbacks_for(:template, :stack_name => stack_name, :sparkle_stack => stack)
            stack_definition = stack.compile.dump!
            stack_resource = resource._dump

            if(stack.parent)
              current_parameters = stack.parent.compile.dump!.to_smash.fetch('Resources', stack_name, 'Properties', 'Parameters', Smash.new)
            else
              current_parameters = Smash.new
            end
            current_stack = c_stack ? c_stack.nested_stacks.detect{|s| s.data[:logical_id] == stack_name} : nil
            if(current_stack && current_stack.data[:parent_stack])
              current_parameters.merge!(current_stack.data[:parent_stack].template.fetch('Resources', stack_name, 'Properties', 'Parameters', Smash.new))
            end
            full_stack_name = stack.root_path.map(&:name).map(&:to_s).join('_')
            unless(config[:print_only])
              result = Smash.new(
                'Parameters' => populate_parameters!(stack,
                  :stack => current_stack,
                  :current_parameters => current_parameters
                )
              )
              resource.properties.delete!(:stack)
              bucket = provider.connection.api_for(:storage).buckets.get(
                config[:nesting_bucket]
              )
              unless(bucket)
                raise "Failed to locate configured bucket for stack template storage (#{bucket})!"
              end
              file = bucket.files.build
              file.name = "#{full_stack_name}.json"
              file.content_type = 'text/json'
              file.body = MultiJson.dump(Sfn::Utils::StackParameterScrubber.scrub!(stack_definition))
              file.save
              url = URI.parse(file.url)
              result.merge!(
                'TemplateURL' => "#{url.scheme}://#{url.host}#{url.path}"
              )
            else
              result = Smash.new(
                'TemplateURL' => "http://example.com/bucket/#{full_stack_name}.json"
              )
            end
            result.each do |k,v|
              resource.properties.set!(k, v)
            end
          end
        end

        # Apply template translation
        #
        # @param template [Hash]
        # @return [Hash]
        def translate_template(template)
          if(klass_name = config[:translate])
            klass = SparkleFormation::Translation.const_get(camel(klass_name))
            args = {
              :parameters => config.fetch(:options, :parameters, Smash.new)
            }
            if(chunk_size = config[:translate_chunk_size])
              args.merge!(
                :options => {
                  :serialization_chunk_size => chunk_size
                }
              )
            end
            translator = klass.new(template, args)
            translator.translate!
            template = translator.translated
            ui.info "#{ui.color('Translation applied:', :bold)} #{ui.color(klass_name, :yellow)}"
          end
          template
        end

        # Set SparkleFormation paths and locate tempate
        #
        # @return [TrueClass]
        def set_paths_and_discover_file!
          if(config[:processing])
            if(!config[:file] && config[:file_path_prompt])
              config[:file] = prompt_for_template
            else
              config[:file] = sparkle_collection.get(:template, config[:file])[:path]
            end
          else
            if(config[:file])
              unless(File.exists?(config[:file]))
                raise Errno::ENOENT.new("No such file - #{config[:file]}")
              end
            else
              raise "Template processing is disabled. Path to serialized template via `--file` required!"
            end
          end
          true
        end

        # Prompt user for template selection
        #
        # @param prefix [String] prefix filter for names
        # @return [String] path to template
        def prompt_for_template(prefix=nil)
          if(prefix)
            collection_name = prefix.split('__').map do |c_name|
              c_name.split('_').map(&:capitalize).join(' ')
            end.join(' / ')
            ui.info "Viewing collection: #{ui.color(collection_name, :bold)}"
            template_names = sparkle_collection.templates.keys.find_all do |t_name|
              t_name.to_s.start_with?(prefix.to_s)
            end
          else
            template_names = sparkle_collection.templates.keys
          end
          collections = template_names.map do |t_name|
            t_name = t_name.to_s.sub(/^#{Regexp.escape(prefix.to_s)}/, '')
            if(t_name.include?('__'))
              c_name = t_name.split('__').first
              [[prefix, c_name].compact.join('') + '__', c_name]
            end
          end.compact.uniq(&:first)
          templates = template_names.map do |t_name|
            t_name = t_name.to_s.sub(/^#{Regexp.escape(prefix.to_s)}/, '')
            unless(t_name.include?('__'))
              [[prefix, t_name].compact.join(''), t_name]
            end
          end.compact
          if(collections.empty? && templates.empty?)
            ui.error 'Failed to locate any templates!'
            return nil
          end
          ui.info "Please select an entry#{ '(or collection to list)' unless collections.empty?}:"
          output = []
          idx = 1
          valid = {}
          unless(collections.empty?)
            output << ui.color('Collections:', :bold)
            collections.each do |full_name, part_name|
              valid[idx] = {:name => full_name, :type => :collection}
              output << [idx, part_name.split('_').map(&:capitalize).join(' ')]
              idx += 1
            end
          end
          unless(templates.empty?)
            output << ui.color('Templates:', :bold)
            templates.each do |full_name, part_name|
              valid[idx] = {:name => full_name, :type => :template}
              output << [idx, part_name.split('_').map(&:capitalize).join(' ')]
              idx += 1
            end
          end
          max = idx.to_s.length
          output.map! do |line|
            if(line.is_a?(Array))
              "  #{line.first}.#{' ' * (max - line.first.to_s.length)} #{line.last}"
            else
              line
            end
          end
          ui.puts "#{output.join("\n")}\n"
          response = nil
          until(valid[response])
            response = ui.ask_question('Enter selection').to_i
          end
          entry = valid[response]
          if(entry[:type] == :collection)
            prompt_for_template(entry[:name])
          else
            sparkle_collection.get(:template, entry[:name])[:path]
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
          extend Sfn::CommandModule::Template::ClassMethods
          include Sfn::CommandModule::Template::InstanceMethods
          include Sfn::Utils::PathSelector
         end
      end

    end
  end
end
