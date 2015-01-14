require 'sfn'

module Sfn
  class Command
    # Export command
    class Export < Command

      include Sfn::CommandModule::Base
      include Snf::Utils::ObjectStorage

      # Run export action
      def execute!
        stack_name = name_args.first
        ui.info "#{ui.color('Stack Export:', :bold)} #{stack_name}"
        ui.confirm 'Perform export'
        stack = provider.stacks.get(stack_name)
        if(stack)
          export_options = Smash.new.tap do |opts|
            [:chef_popsicle, :chef_environment_parameter, :ignore_parameters].each do |key|
              opts[key] = config[key] unless config[key].nil?
            end
          end
          exporter = Sfn::Utils::StackExporter.new(stack, export_options)
          result = exporter.export
          outputs = [
            write_to_file(result, stack),
            write_to_bucket(result, stack)
          ].compact
          if(outputs.empty?)
            ui.warn 'No persistent output location defined. Printing export:'
            ui.info _format_json(result)
          end
          ui.info "#{ui.color('Stack export', :bold)} (#{name_args.first}): #{ui.color('complete', :green)}"
          unless(outputs.empty?)
            outputs.each do |output|
              ui.info ui.color("  -> #{output}", :blue)
            end
          end
        else
          ui.fatal "Failed to discover requested stack: #{ui.color(stack_name, :red, :bold)}"
          exit -1
        end
      end

      # Generate file name for stack export JSON contents
      #
      # @param stack [Miasma::Models::Orchestration::Stack]
      # @return [String] file name
      def export_file_name(stack)
        name = config[:file]
        if(name)
          if(name.respond_to?(:call))
            name.call(stack)
          else
            name.to_s
          end
        else
          "#{stack.stack_name}-#{Time.now.to_i}.json"
        end
      end

      # Write stack export to local file
      #
      # @param payload [Hash] stack export payload
      # @param stack [Misama::Stack::Orchestration::Stack]
      # @return [String, NilClass] path to file
      def write_to_file(payload, stack)
        raise NotImplementedError
        if(config[:path])
          full_path = File.join(
            config[:path],
            export_file_name(stack)
          )
          _, bucket, path = full_path.split('/', 3)
          directory = provider.service_for(:storage,
            :provider => :local,
            :local_root => '/'
          ).directories.get(bucket)
          file_store(payload, path, directory)
        end
      end

      # Write stack export to remote bucket
      #
      # @param payload [Hash] stack export payload
      # @param stack [Miasma::Models::Orchestration::Stack]
      # @return [String, NilClass] remote bucket key
      def write_to_bucket(payload, stack)
        raise NotImplementedError
        if(bucket = config[:bucket])
          key_path = File.join(*[
              bucket_prefix(stack),
              export_file_name(stack)
            ].compact
          )
          file_store(payload, key_path, provider.service_for(:storage).directories.get(bucket))
        end
      end

    end
  end
end
