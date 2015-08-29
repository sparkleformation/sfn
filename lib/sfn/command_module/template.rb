require 'sfn'
require 'sparkle_formation'

require 'pathname'

module Sfn
  module CommandModule
    # Template handling helper methods
    module Template

      # cloudformation directories that should be ignored
      TEMPLATE_IGNORE_DIRECTORIES = %w(components dynamics registry)

      module InstanceMethods

        # Load the template file
        #
        # @param args [Symbol] options (:allow_missing)
        # @return [Hash] loaded template
        def load_template_file(*args)
          c_stack = (args.detect{|i| i.is_a?(Hash)} || {})[:stack]
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
              sf = SparkleFormation.compile(config[:file], :sparkle)
              if(sf.nested? && !sf.isolated_nests?)
                raise TypeError.new('Template does not contain isolated stack nesting! Sfn does not support mixed mixed resources within root stack!')
              end
              run_callbacks_for(:stack, :stack_name => arguments.first, :sparkle_stack => sf)
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
              run_callbacks_for(:stack, :stack_name => arguments.first, :hash_stack => template)
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
            run_callbacks_for(:stack, :stack_name => stack_name, :sparkle_stack => stack)
            stack_definition = stack.compile.dump!
            bucket = provider.connection.api_for(:storage).buckets.get(
              config[:nesting_bucket]
            )
            if(config[:print_only])
              template_url = "http://example.com/bucket/#{name_args.first}_#{stack_name}.json"
            else
              resource.properties.delete!(:stack)
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
            run_callbacks_for(:stack, :stack_name => stack_name, :sparkle_stack => stack)
            stack_definition = stack.compile.dump!
            stack_resource = resource._dump
            bucket = provider.connection.api_for(:storage).buckets.get(
              config[:nesting_bucket]
            )
            c_defaults = ui.auto_default
            ui.auto_default = true if config[:print_only]
            result = Smash.new(
              'Parameters' => populate_parameters!(stack,
                :stack => c_stack ? c_stack.nested_stacks.detect{|s| s.attributes[:logical_id] == stack_name} : nil,
                :current_parameters => stack_resource['Properties'].fetch('Parameters', {})
              )
            )
            ui.auto_default = c_defaults
            if(config[:print_only])
              result.merge!(
                'TemplateURL' => "http://example.com/bucket/#{name_args.first}_#{stack_name}.json"
              )
            else
              resource.properties.delete!(:stack)
              unless(bucket)
                raise "Failed to locate configured bucket for stack template storage (#{bucket})!"
              end
              file = bucket.files.build
              file.name = "#{name_args.first}_#{stack_name}.json"
              file.content_type = 'text/json'
              file.body = MultiJson.dump(Sfn::Utils::StackParameterScrubber.scrub!(stack_definition))
              file.save
              url = URI.parse(file.url)
              result.merge!(
                'TemplateURL' => "#{url.scheme}://#{url.host}#{url.path}"
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
