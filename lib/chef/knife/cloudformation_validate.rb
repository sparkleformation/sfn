require 'sparkle_formation'
require 'pathname'
require 'knife-cloudformation/cloudformation_base'
require 'chef/knife/cloudformation_create'

class Chef
  class Knife
    class CloudformationValidate < CloudformationCreate

      include KnifeCloudformation::KnifeBase

      banner 'knife cloudformation validate'

      module Options
        class << self
          def included(klass)
            klass.class_eval do

              option(:all,
                :long => '--[no-]all',
                :short => '-a',
                :description => 'Validate all discoverable templates',
                :boolean => true,
                :default => false,
                :proc => lambda {|val| Chef::Config[:knife][:cloudformation][:validate_all] = val }
              )
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
            end
          end
        end
      end

      include Options

      def run
        failed = false
        if(Chef::Config[:knife][:cloudformation][:validate_all])
          files = Dir.glob('cloudformation/**/*.rb').map do |path|
            unless(path.include?('cloudformation/components') || path.include?('cloudformation/dynamics'))
              File.expand_path(path)
            end
          end.compact
        else
          files = [Chef::Config[:knife][:cloudformation][:file]]
        end
        files.each do |path|
          Chef::Config[:knife][:cloudformation][:file] = path
          unless(Chef::Config[:knife][:cloudformation][:template])
            set_paths_and_discover_file!
            unless(File.exists?(Chef::Config[:knife][:cloudformation][:file].to_s))
              ui.fatal "Invalid formation file path provided: #{Chef::Config[:knife][:cloudformation][:file]}"
              exit 1
            end
          end

          if(Chef::Config[:knife][:cloudformation][:template])
            file = Chef::Config[:knife][:cloudformation][:template]
          elsif(Chef::Config[:knife][:cloudformation][:processing])
            file = SparkleFormation.compile(Chef::Config[:knife][:cloudformation][:file])
          else
            file = _from_json(File.read(Chef::Config[:knife][:cloudformation][:file]))
          end
          ui.info "#{ui.color('Cloud Formation Validation: ', :bold)} #{Chef::Config[:knife][:cloudformation][:file].sub(Dir.pwd, '').sub(%r{^/}, '')}"
          begin
            aws.aws(:cloud_formation).validate_template('TemplateBody' => _to_json(file))
            ui.info ui.color('  -> VALID', :bold, :green)
          rescue => e
            ui.info ui.color('  -> INVALID', :bold, :red)
            ui.fatal e.message
            failed = true
          end
        end
        exit 1 if failed
      end

    end
  end
end
