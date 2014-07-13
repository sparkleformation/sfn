require 'knife-cloudformation'
require 'sparkle_formation'

module KnifeCloudformation
  module Knife
    # Template handling helper methods
    module Template

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
              SparkleFormation.compile(Chef::Config[:knife][:cloudformation][:file])
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
            translator = klass.new(template, :parameters => Chef::Config[:knife][:cloudformation][:options][:parameters])
            translator.translate!
            template = translator.translated
            ui.info "#{ui.color('Translation applied:', :bold)} #{ui.color(klass_name, :yellow)}"
          end
          template
        end

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
          Chef::Config[:knife][:cloudformation][:file] = prompt_for_file(
            Chef::Config[:knife][:cloudformation][:base_directory] || File.join(Dir.pwd, 'cloudformation')
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

      # Prompt user for file selection
      #
      # @param dir [String] path to directory
      # @return [String] file path
      def prompt_for_file(dir)
        directory = Dir.new(dir)
        directories = directory.map do |d|
          if(!d.start_with?('.') && !%w(dynamics registry components).include?(d) && File.directory?(path = File.join(dir, d)))
            path
          end
        end.compact.sort
        files = directory.map do |f|
          if(!f.start_with?('.') && File.file?(path = File.join(dir, f)))
            path
          end
        end.compact.sort
        if(directories.empty? && files.empty?)
          ui.fatal 'No formation paths discoverable!'
        else
          output = ['Please select the formation to create']
          output << '(or directory to list):' unless directories.empty?
          ui.info output.join(' ')
          output.clear
          idx = 1
          valid = {}
          unless(directories.empty?)
            output << ui.color('Directories:', :bold)
            directories.each do |path|
              valid[idx] = {:path => path, :type => :directory}
              output << [idx, "#{File.basename(path).sub('.rb', '').split(/[-_]/).map(&:capitalize).join(' ')}"]
              idx += 1
            end
          end
          unless(files.empty?)
            output << ui.color('Templates:', :bold)
            files.each do |path|
              valid[idx] = {:path => path, :type => :file}
              output << [idx, "#{File.basename(path).sub('.rb', '').split(/[-_]/).map(&:capitalize).join(' ')}"]
              idx += 1
            end
          end
          max = idx.to_s.length
          output.map! do |o|
            if(o.is_a?(Array))
              "  #{o.first}.#{' ' * (max - o.first.to_s.length)} #{o.last}"
            else
              o
            end
          end
          ui.info "#{output.join("\n")}\n"
          response = ask_question('Enter selection: ').to_i
          unless(valid[response])
            ui.fatal 'How about using a real value'
            exit 1
          else
            entry = valid[response.to_i]
            if(entry[:type] == :directory)
              prompt_for_file(entry[:path])
            else
              Chef::Config[:knife][:cloudformation][:file] = entry[:path]
            end
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
          extend KnifeCloudformation::Knife::Template::ClassMethods
          include KnifeCloudformation::Knife::Template::InstanceMethods

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

        end
      end

    end
  end
end
