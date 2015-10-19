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
              result = cur_val
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

        # Load the template file
        #
        # @param args [Symbol] options (:allow_missing)
        # @return [Hash] loaded template
        def load_template_file(*args)
          unless(config[:template])
            set_paths_and_discover_file!
            unless(File.exists?(config[:file].to_s))
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
                f_name = []
                f_form = formation
                while(f_form)
                  f_name.push f_form.name
                  f_form = f_form.parent
                end
                f_name = f_name.reverse.map(&:to_s).join('_')
                current_state = compile_state.fetch(f_name, Smash.new)
                if(formation.compile_state)
                  current_state = current_state.merge(formation.compile_state)
                end
                ui.info "#{ui.color('Compile time parameters:', :bold)} - template: #{ui.color(formation.name, :green, :bold)}"
                formation.parameters.each do |k,v|
                  current_state[k] = request_compile_parameter(k, v, current_state[k], !!formation.parent)
                end
                formation.compile_state = current_state
              end
              if(sf.nested? && !sf.isolated_nests?)
                raise TypeError.new('Template does not contain isolated stack nesting! Cannot process in existing state.')
              end
              if(sf.nested? && config[:apply_nesting])
                sf.apply_nesting do |stack_name, stack_definition|
                  if(config[:print_only])
                    # "http://example.com/bucket/#{name_args.first}_#{stack_name}.json"
                    stack_definition
                  else
                    bucket = provider.connection.api_for(:storage).buckets.get(
                      config[:nesting_bucket]
                    )
                    unless(bucket)
                      raise "Failed to locate configured bucket for stack template storage (#{bucket})!"
                    end
                    file = bucket.files.build
                    file.name = "#{name_args.first}_#{stack_name}.json"
                    file.content_type = 'text/json'
                    file.body = MultiJson.dump(Sfn::Utils::StackParameterScrubber.scrub!(stack_definition))
                    file.save
                    # TODO: what if we need extra params?
                    url = URI.parse(file.url)
                    "#{url.scheme}://#{url.host}#{url.path}"
                  end
                end
              else
                sf.dump.merge('sfn_nested_stack' => !!sf.nested?)
              end
            else
              _from_json(File.read(config[:file]))
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
          if(config[:base_directory])
            SparkleFormation.sparkle_path = config[:base_directory]
          end
          if(!config[:file] && config[:file_path_prompt])
            root = File.expand_path(
              config.fetch(:base_directory,
                File.join(Dir.pwd, 'cloudformation')
              )
            ).split('/')
            bucket = root.pop
            root = root.join('/')
            directory = File.join(root, bucket)
            config[:file] = prompt_for_file(directory,
              :directories_name => 'Collections',
              :files_name => 'Templates',
              :ignore_directories => TEMPLATE_IGNORE_DIRECTORIES
            )
          else
            unless(Pathname(config[:file].to_s).absolute?)
              base_dir = config[:base_directory].to_s
              file = config[:file].to_s
              pwd = Dir.pwd
              config[:file] = [
                File.join(base_dir, file),
                File.join(pwd, file),
                File.join(pwd, 'cloudformation', file)
              ].detect do |file_path|
                File.file?(file_path)
              end
            end
          end
          true
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
