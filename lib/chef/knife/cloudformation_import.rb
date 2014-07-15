require 'stringio'
require 'knife-cloudformation'

class Chef
  class Knife
    # Cloudformation import command
    class CloudformationImport < Knife

      include KnifeCloudformation::Knife::Base
      include KnifeCloudformation::Utils::ObjectStorage

      banner 'knife cloudformation import NEW_STACK_NAME [JSON_EXPORT_FILE]'

      option(:path,
        :long => '--import-path PATH',
        :description => 'Directory path JSON export files are located',
        :proc => lambda{|v| Chef::Config[:knife][:cloudformation][:import][:path] = v}
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
      def run
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
            json_file = remote_discovery(stack)
          else
            json_file = local_discovery(stack)
          end
        end
        if(File.exists?(json_file) || json_file.is_a?(IO))
          content = json_file.is_a?(IO) ? json_file.read : File.read(json_file)
          export = Mash.new(_from_json(content))
          creator = Chef::Knife::CloudformationCreate.new
          creator.name_args = [stack_name]
          Chef::Config[:knife][:cloudformation][:template] = stack[:stack][:template]
          Chef::Config[:knife][:cloudformation][:options] = stack[:stack][:options]
          ui.info '  - Starting creation of import'
          creator.run
          ui.info "#{ui.color('Stack Import', :bold)} (#{json_file}): #{ui.color('complete', :green)}"
        else
          ui.fatal "Failed to locate JSON export file (#{json_file})"
          exit 1
        end
      end

      # Generate bucket prefix
      #
      # @param stack [Fog::Orchestration::Stack]
      # @return [String, NilClass]
      def bucket_prefix(stack)
        if(prefix = Chef::Config[:knife][:cloudformation][:import][:bucket_prefix])
          if(prefix.respond_to?(:cal))
            prefix.call(stack)
          else
            prefix.to_s
          end
        end
      end

      # Discover remote file
      #
      # @param stack [Fog::Orchestration::Stack]
      # @return [IO] stack export IO
      def remote_discovery(stack)
        storage = provider.service_for(:storage)
        directory = storage.directories.get(
          Chef::Config[:knife][:cloudformation][:import][:bucket]
        )
        file = prompt_for_file(
          directory,
          :directories_name => 'Collections',
          :files_names => 'Exports',
          :filter_prefix => bucket_prefix(stack)
        )
        if(file)
          remote_file = storage.files.get(file)
          StringIO.new(remote_file.body)
        end
      end

      # Discover remote file
      #
      # @param stack [Fog::Orchestration::Stack]
      # @return [IO] stack export IO
      def local_discovery(stack)
        bucket, root = Chef::Config[:knife][:cloudformation][:import][:path].reverse.split('/', 2).map(&:reverse!)
        storage = provider.service_for(:storage,
          :provider => :local,
          :local_root => root
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
