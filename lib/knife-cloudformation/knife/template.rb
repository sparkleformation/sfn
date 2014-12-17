require 'knife-cloudformation'
require 'sparkle_formation'

module KnifeCloudformation
  module Knife
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
          unless(Chef::Config[:knife][:cloudformation][:template])
            set_paths_and_discover_file!
            unless(File.exists?(Chef::Config[:knife][:cloudformation][:file].to_s))
              unless(args.include?(:allow_missing))
                ui.fatal "Invalid formation file path provided: #{Chef::Config[:knife][:cloudformation][:file]}"
                exit 1
              end
            end
          end
          if(Chef::Config[:knife][:cloudformation][:template])
            Chef::Config[:knife][:cloudformation][:template]
          elsif(Chef::Config[:knife][:cloudformation][:file])
            if(Chef::Config[:knife][:cloudformation][:processing])
              sf = SparkleFormation.compile(Chef::Config[:knife][:cloudformation][:file], :sparkle)
              if(sf.nested? && Chef::Config[:knife][:cloudformation][:apply_nesting])
                sf.apply_nesting do |stack_name, stack_definition|
                  bucket = provider.connection.api_for(:storage).buckets.get(
                    Chef::Config[:knife][:cloudformation][:nesting_bucket]
                  )
                  unless(bucket)
                    raise "Failed to locate configured bucket for stack template storage (#{bucket})!"
                  end
                  file = bucket.files.build
                  file.name = "#{name_args.first}_#{stack_name}.json"
                  file.content_type = 'text/json'
                  file.body = MultiJson.dump(KnifeCloudformation::Utils::StackParameterScrubber.scrub!(stack_definition))
                  file.save
                  # TODO: what if we need extra params?
                  url = URI.parse(file.url)
                  "#{url.scheme}://#{url.host}#{url.path}"
                end
              else
                if(sf.nested? && !sf.isolated_nests?)
                  raise TypeError.new('Template does not contain isolated stack nesting! Cannot process in existing state.')
                end
                sf.dump
              end
            else
              _from_json(File.read(Chef::Config[:knife][:cloudformation][:file]))
            end
          end
        end

        # Apply template translation
        #
        # @param template [Hash]
        # @return [Hash]
        def translate_template(template)
          if(klass_name = Chef::Config[:knife][:cloudformation][:translate])
            klass = SparkleFormation::Translation.const_get(camel(klass_name))
            args = {
              :parameters => Chef::Config[:knife][:cloudformation][:options][:parameters]
            }
            if(chunk_size = Chef::Config[:knife][:cloudformation][:translate_chunk_size])
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
          if(Chef::Config[:knife][:cloudformation][:base_directory])
            SparkleFormation.components_path = File.join(
              Chef::Config[:knife][:cloudformation][:base_directory], 'components'
            )
            SparkleFormation.dynamics_path = File.join(
              Chef::Config[:knife][:cloudformation][:base_directory], 'dynamics'
            )
          end
          if(!Chef::Config[:knife][:cloudformation][:file] && Chef::Config[:knife][:cloudformation][:file_path_prompt])
            root = File.expand_path(
              Chef::Config[:knife][:cloudformation].fetch(:base_directory,
                File.join(Dir.pwd, 'cloudformation')
              )
            ).split('/')
            bucket = root.pop
            root = root.join('/')
            directory = File.join(root, bucket)
            Chef::Config[:knife][:cloudformation][:file] = prompt_for_file(directory,
              :directories_name => 'Collections',
              :files_name => 'Templates',
              :ignore_directories => TEMPLATE_IGNORE_DIRECTORIES
            )
          else
            unless(Pathname(Chef::Config[:knife][:cloudformation][:file].to_s).absolute?)
              base_dir = Chef::Config[:knife][:cloudformation][:base_directory].to_s
              file = Chef::Config[:knife][:cloudformation][:file].to_s
              pwd = Dir.pwd
              Chef::Config[:knife][:cloudformation][:file] = [
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
          extend KnifeCloudformation::Knife::Template::ClassMethods
          include KnifeCloudformation::Knife::Template::InstanceMethods
          include KnifeCloudformation::Utils::PathSelector

          option(:processing,
            :long => '--[no-]processing',
            :description => 'Call the unicorns and explode the glitter bombs',
            :boolean => true,
            :default => false,
            :proc => lambda {|val| Chef::Config[:knife][:cloudformation][:processing] = val }
          )
          option(:file,
            :short => '-f PATH',
            :long => '--file PATH',
            :description => 'Path to Cloud Formation to process',
            :proc => lambda {|val|
              Chef::Config[:knife][:cloudformation][:file] = val
            }
          )
          option(:file_path_prompt,
            :long => '--[no-]file-path-prompt',
            :description => 'Interactive prompt for template path discovery',
            :boolean => true,
            :default => true,
            :proc => lambda {|val|
              Chef::Config[:knife][:cloudformation][:file_path_prompt] = val
            }
          )
          option(:base_directory,
            :long => '--cloudformation-directory PATH',
            :description => 'Path to cloudformation directory',
            :proc => lambda {|val| Chef::Config[:knife][:cloudformation][:base_directory] = val}
          )
          option(:no_base_directory,
            :long => '--no-cloudformation-directory',
            :description => 'Unset any value used for cloudformation path',
            :proc => lambda {|*val| Chef::Config[:knife][:cloudformation][:base_directory] = nil}
          )
          option(:translate,
            :long => '--translate PROVIDER',
            :description => 'Translate generated template to given provider',
            :proc => lambda {|val| Chef::Config[:knife][:cloudformation][:translate] = val}
          )
          option(:translate_chunk,
            :long => '--translate-chunk-size SIZE',
            :description => 'Chunk length for serialization',
            :proc => lambda {|val| Chef::Config[:knife][:cloudformation][:translate_chunk_size] = val}
          )
          option(:apply_nesting,
            :long => '--[no-]apply-nesting',
            :description => 'Apply stack nesting',
            :default => false,
            :boolean => true,
            :proc => lambda{|val| Chef::Config[:knife][:cloudformation][:apply_nesting] = val}
          )
          option(:nesting_bucket,
            :long => '--nesting-bucket',
            :description => 'Bucket to use for storing nested stack templates',
            :proc => lambda{|val| Chef::Config[:knife][:cloudformation][:nesting_bucket] = val}
          )

          Chef::Config[:knife][:cloudformation][:file_path_prompt] = true

        end

      end

    end
  end
end
