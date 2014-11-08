require 'knife-cloudformation'

class Chef
  class Knife
    # Cloudformation export command
    class CloudformationExport < Knife

      include KnifeCloudformation::Knife::Base
      include KnifeCloudformation::Utils::ObjectStorage

      banner 'knife cloudformation export STACK_NAME'

      option(:export_name,
        :long => '--export-file-name NAME',
        :description => 'File basename to contain the export. Can be callable block if defined within configuration',
        :proc => lambda{|v| Chef::Config[:knife][:cloudformation][:export][:name] = v}
      )

      option(:path,
        :long => '--export-path PATH',
        :description => 'Directory path write export JSON file',
        :proc => lambda{|v| Chef::Config[:knife][:cloudformation][:export][:path] = v}
      )

      option(:bucket,
        :long => '--export-bucket BUCKET_NAME',
        :description => 'Remote file bucket to write export JSON file',
        :proc => lambda{|v| Chef::Config[:knife][:cloudformation][:export][:bucket] = v}
      )

      option(:bucket_prefix,
        :long => '--bucket-key-prefix PREFIX',
        :description => 'Key prefix for file storage in bucket. Can be callable block if defined within configuration',
        :proc => lambda{|v| Chef::Config[:knife][:cloudformation][:export][:bucket_prefix] = v}
      )

      option(:ignore_parameters,
        :short => '-P NAME',
        :long => '--exclude-parameter NAME',
        :description => 'Exclude parameter from export (can be used multiple times)',
        :proc => lambda{|v|
          Chef::Config[:knife][:cloudformation][:export][:ignore_parameters].push(v).uniq!
        }
      )

      option(:chef_environment_parameter,
        :long => '--chef-environment-parameter NAME',
        :description => 'Parameter used within stack to specify Chef environment',
        :proc => lambda{|v|
          Chef::Config[:knife][:cloudformation][:export][:chef_environment_parameter] = v
        }
      )

      option(:chef_popsicle,
        :long => '--[no-]freeze-run-list',
        :boolean => true,
        :default => true,
        :description => 'Freezes first run files',
        :proc => lambda{|v| Chef::Config[:knife][:cloudformation][:export][:chef_popsicle] = v }
      )

      unless(Chef::Config[:knife][:cloudformation].has_key?(:export))
        Chef::Config[:knife][:cloudformation][:export] = Mash.new(
          :credentials => Mash.new,
          :ignore_parameters => []
        )
      end

      # Run export action
      def run
        stack_name = name_args.first
        ui.info "#{ui.color('Stack Export:', :bold)} #{stack_name}"
        ui.confirm 'Perform export'
        stack = provider.stacks.get(stack_name)
        if(stack)
          export_options = Mash.new.tap do |opts|
            [:chef_popsicle, :chef_environment_parameter, :ignore_parameters].each do |key|
              unless(Chef::Config[:knife][:cloudformation][:export][key].nil?)
                opts[key] = Chef::Config[:knife][:cloudformation][:export][key]
              end
            end
          end
          exporter = KnifeCloudformation::Utils::StackExporter.new(stack, export_options)
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
        name = Chef::Config[:knife][:cloudformation][:export][:file]
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
        if(Chef::Config[:knife][:cloudformation][:export][:path])
          full_path = File.join(
            File.expand_path(Chef::Config[:knife][:cloudformation][:export][:path]),
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
        if(bucket = Chef::Config[:knife][:cloudformation][:export][:bucket])
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
