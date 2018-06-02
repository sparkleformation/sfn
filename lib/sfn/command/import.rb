require "stringio"
require "sfn"

module Sfn
  class Command
    # Import command
    class Import < Command
      include Sfn::CommandModule::Base
      include Sfn::Utils::JSON
      include Sfn::Utils::ObjectStorage
      include Sfn::Utils::PathSelector

      # Run the import action
      def execute!
        raise NotImplementedError.new "Implementation updates required"
        stack_name, json_file = name_args
        ui.info "#{ui.color("Stack Import:", :bold)} #{stack_name}"
        unless json_file
          entries = [].tap do |_entries|
            _entries.push("s3") if config[:bucket]
            _entries.push("fs") if config[:path]
          end
          if entries.size > 1
            valid = false
            until valid
              answer = ui.ask_question("Import via file system (fs) or remote bucket (remote)?", :default => "remote")
              valid = true if %w(remote fs).include?(answer)
              entries = [answer]
            end
          elsif entries.size < 1
            ui.fatal "No path or bucket set. Unable to perform dynamic lookup!"
            exit 1
          end
          case entries.first
          when "remote"
            json_file = remote_discovery
          else
            json_file = local_discovery
          end
        end
        if File.exists?(json_file) || json_file.is_a?(IO)
          content = json_file.is_a?(IO) ? json_file.read : File.read(json_file)
          export = Mash.new(_from_json(content))
          begin
            creator = namespace.const_val(:Create).new(
              Smash.new(
                :template => _from_json(export[:stack][:template]),
                :options => _from_json(export[:stack][:options]),
              ),
              [stack_name]
            )
            ui.info "  - Starting creation of import"
            creator.execute!
            ui.info "#{ui.color("Stack Import", :bold)} (#{json_file}): #{ui.color("complete", :green)}"
          rescue => e
            ui.fatal "Failed to import stack: #{e}"
            debug "#{e.class}: #{e}\n#{e.backtrace.join("\n")}"
            raise
          end
        else
          ui.fatal "Failed to locate JSON export file (#{json_file})"
          raise
        end
      end

      # Generate bucket prefix
      #
      # @return [String, NilClass]
      def bucket_prefix
        if prefix = config[:bucket_prefix]
          if prefix.respond_to?(:call)
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
        directory = storage.directories.get(config[:bucket])
        file = prompt_for_file(
          directory,
          :directories_name => "Collections",
          :files_names => "Exports",
          :filter_prefix => bucket_prefix,
        )
        if file
          remote_file = storage.files.get(file)
          StringIO.new(remote_file.body)
        end
      end

      # Discover remote file
      #
      # @return [IO] stack export IO
      def local_discovery
        _, bucket = config[:path].split("/", 2)
        storage = provider.service_for(:storage,
                                       :provider => :local,
                                       :local_root => "/")
        directory = storage.directories.get(bucket)
        prompt_for_file(
          directory,
          :directories_name => "Collections",
          :files_names => "Exports",
        )
      end
    end
  end
end
