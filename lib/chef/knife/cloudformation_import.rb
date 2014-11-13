require 'stringio'
require 'knife-cloudformation'

class Chef
  class Knife
    # Cloudformation import command
    class CloudformationImport < Knife

      include KnifeCloudformation::Knife::Base
      include KnifeCloudformation::Utils::JSON
      include KnifeCloudformation::Utils::ObjectStorage
      include KnifeCloudformation::Utils::PathSelector

      banner 'knife cloudformation import NEW_STACK_NAME [JSON_EXPORT_FILE]'

      option(:path,
        :long => '--import-path PATH',
        :description => 'Directory path JSON export files are located',
        :proc => lambda{|v|
          Chef::Config[:knife][:cloudformation][:import][:path] = File.expand_path(v)
        }
      )

      option(:bucket,
        :long => '--export-bucket BUCKET_NAME',
        :description => 'Remote file bucket JSON export files are located',
        :proc => lambda{|v| Chef::Config[:knife][:cloudformation][:import][:bucket] = v}
      )

      option(:bucket_prefix,
        :long => '--bucket-key-prefix PREFIX',
        :description => 'Key prefix for file storage in bucket. Can be callable block if defined within configuration',
        :proc => lambda{|v| Chef::Config[:knife][:cloudformation][:import][:bucket_prefix] = v}
      )

      unless(Chef::Config[:knife][:cloudformation].has_key?(:import))
        Chef::Config[:knife][:cloudformation][:import] = Mash.new
      end

      # Run the import action
      def _run
        stack_name, json_file = name_args
        ui.info "#{ui.color('Stack Import:', :bold)} #{stack_name}"
        unless(json_file)
          entries = [].tap do |_entries|
            _entries.push('s3') if Chef::Config[:knife][:cloudformation][:import][:bucket]
            _entries.push('fs') if Chef::Config[:knife][:cloudformation][:import][:path]
          end
          if(entries.size > 1)
            valid = false
            until(valid)
              answer = ui.ask_question('Import via file system (fs) or remote bucket (remote)?', :default => 'remote')
              valid = true if %w(remote fs).include?(answer)
              entries = [answer]
            end
          elsif(entries.size < 1)
            ui.fatal 'No path or bucket set. Unable to perform dynamic lookup!'
            exit 1
          end
          case entries.first
          when 'remote'
            json_file = remote_discovery
          else
            json_file = local_discovery
          end
        end
        if(File.exists?(json_file) || json_file.is_a?(IO))
          content = json_file.is_a?(IO) ? json_file.read : File.read(json_file)
          export = Mash.new(_from_json(content))
          begin
            creator = Chef::Knife::CloudformationCreate.new
            creator.name_args = [stack_name]
            Chef::Config[:knife][:cloudformation][:template] = _from_json(export[:stack][:template])
            Chef::Config[:knife][:cloudformation][:options] = export[:stack][:options]
            ui.info '  - Starting creation of import'
            creator.run
            ui.info "#{ui.color('Stack Import', :bold)} (#{json_file}): #{ui.color('complete', :green)}"
          rescue => e
            ui.fatal "Failed to import stack: #{e}"
            debug "#{e.class}: #{e}\n#{e.backtrace.join("\n")}"
            exit -1
          end
        else
          ui.fatal "Failed to locate JSON export file (#{json_file})"
          exit 1
        end
      end

      # Generate bucket prefix
      #
      # @return [String, NilClass]
      def bucket_prefix
        if(prefix = Chef::Config[:knife][:cloudformation][:import][:bucket_prefix])
          if(prefix.respond_to?(:cal))
            prefix.call
          else
            prefix.to_s
          end
        end
      end

      # Discover remote file
      #
      # @return [IO] stack export IO
      def remote_discovery
        storage = provider.service_for(:storage)
        directory = storage.directories.get(
          Chef::Config[:knife][:cloudformation][:import][:bucket]
        )
        file = prompt_for_file(
          directory,
          :directories_name => 'Collections',
          :files_names => 'Exports',
          :filter_prefix => bucket_prefix
        )
        if(file)
          remote_file = storage.files.get(file)
          StringIO.new(remote_file.body)
        end
      end

      # Discover remote file
      #
      # @return [IO] stack export IO
      def local_discovery
        _, bucket = Chef::Config[:knife][:cloudformation][:import][:path].split('/', 2)
        storage = provider.service_for(:storage,
          :provider => :local,
          :local_root => '/'
        )
        directory = storage.directories.get(bucket)
        prompt_for_file(
          directory,
          :directories_name => 'Collections',
          :files_names => 'Exports'
        )
      end

    end
  end
end
