require 'knife-cloudformation/cloudformation_base'
require 'knife-cloudformation/export'

class Chef
  class Knife
    class CloudformationExport < Knife

      include KnifeCloudformation::KnifeBase

      banner 'knife cloudformation export NAME'

      # TODO: Add option for s3 exports

      option(:s3_bucket,
        :long => '--s3-bucket NAME',
        :description => 'S3 bucket for export storage',
        :proc => lambda{|v| Chef::Config[:knife][:cloudformation][:s3_export] = v }
      )

      option(:s3_prefix,
        :long => '--s3-prefix PREFIX',
        :description => 'Directory prefix within S3 bucket to store the export',
        :proc => lambda{|v| Chef::Config[:knife][:cloudformation][:s3_prefix] = v }
      )

      option(:path,
        :long => '--export-path PATH',
        :description => 'Path to write export JSON file',
        :proc => lambda{|v| Chef::Config[:knife][:cloudformation][:export_path] = v }
      )

      option(:ignore_parameters,
        :short => '-P NAME',
        :long => '--exclude-parameter NAME',
        :description => 'Exclude parameter from export (can be used multiple times)',
        :proc => lambda{|v|
          Chef::Config[:knife][:cloudformation][:ignore_parameters] ||= []
          Chef::Config[:knife][:cloudformation][:ignore_parameters].push(v).uniq!
        }
      )

      option(:chef_environment_parameter,
        :long => '--chef-environment-parameter NAME',
        :description => 'Parameter used within stack to specify Chef environment',
        :proc => lambda{|v|
          Chef::Config[:knife][:cloudformation][:chef_environment_parameter] = v
        }
      )

      option(:chef_popsicle,
        :long => '--[no-]freeze-run-list',
        :boolean => true,
        :default => true,
        :description => 'Freezes first run files',
        :proc => lambda{|v| Chef::Config[:knife][:cloudformation][:chef_popsicle] = v }
      )

      def run
        ui.info "#{ui.color('Stack Export:', :bold)} #{name_args.first}"
        ui.confirm 'Perform export'
        ex_opts = {}
        [:chef_popsicle, :chef_environment_parameter, :ignore_parameters].each do |key|
          unless(Chef::Config[:knife][:cloudformation][key].nil?)
            ex_opts[key] = Chef::Config[:knife][:cloudformation][key]
          end
        end
        exporter = KnifeCloudformation::Export.new(name_args.first, ex_opts.merge(:aws_commons => aws))
        result = exporter.export
        outputs = [write_to_file(result), write_to_s3(result)].compact
        if(outputs.empty?)
          ui.info _format_json(result)
        end
        ui.info "#{ui.color('Stack export', :bold)} (#{name_args.first}): #{ui.color('complete', :green)}"
        unless(outputs.empty?)
          outputs.each do |output|
            ui.info ui.color("  -> #{output}", :blue)
          end
        end
      end

      def write_to_file(payload)
        if(Chef::Config[:knife][:cloudformation][:export_path])
          file_path = File.join(
            Chef::Config[:knife][:cloudformation][:export_path],
            "#{name_args.first}-#{Time.now.to_i}.json"
          )
          File.open(file_path, 'w') do |file|
            file.puts _format_json(payload)
          end
          file_path
        end
      end

      def write_to_s3(payload)
        if(bucket = Chef::Config[:knife][:cloudformation][:s3_bucket])
          s3_path = File.join(
            Chef::Config[:knife][:cloudformation][:s3_prefix],
            "#{name_args.first}-#{Time.now.to_i}.json"
          )
          aws.aws(:storage).put_object(bucket, s3_path, _format_json(payload))
          "s3://#{File.join(bucket, s3_path)}"
        end
      end

    end
  end
end
