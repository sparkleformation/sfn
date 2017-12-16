require 'sfn'
require 'fileutils'

module Sfn
  class Command
    # Init command
    class Init < Command
      include Sfn::CommandModule::Base

      INIT_DIRECTORIES = [
        'sparkleformation/dynamics',
        'sparkleformation/components',
        'sparkleformation/registry',
      ]

      # Run the init command to initialize new project
      def execute!
        unless name_args.size == 1
          raise ArgumentError.new 'Please provide path argument only for project initialization'
        else
          path = name_args.first
        end
        if File.file?(path)
          raise "Cannot create project directory. Given path is a file. (`#{path}`)"
        end
        if File.directory?(path)
          ui.warn "Project directory already exists at given path. (`#{path}`)"
          ui.confirm 'Overwrite existing files?'
        end
        run_action 'Creating base project directories' do
          INIT_DIRECTORIES.each do |new_dir|
            FileUtils.mkdir_p(File.join(path, new_dir))
          end
          nil
        end
        run_action 'Creating project bundle' do
          File.open(File.join(path, 'Gemfile'), 'w') do |file|
            file.puts "source 'https://rubygems.org'\n\ngem 'sfn'"
          end
          nil
        end
        ui.info 'Generating .sfn configuration file'
        Dir.chdir(path) do
          Conf.new({:generate => true}, []).execute!
        end
        ui.info 'Installing project bundle'
        Dir.chdir(path) do
          if defined?(Bundler)
            Bundler.clean_system('bundle install')
          else
            system('bundle install')
          end
        end
        ui.info 'Project initialization complete!'
        ui.puts "  Project path -> #{File.expand_path(path)}"
      end
    end
  end
end
