require 'knife-cloudformation/cloudformation_base'
require 'knife-cloudformation/export'

class Chef
  class Knife
    class CloudformationExport < Knife

      include KnifeCloudformation::KnifeBase

      banner 'knife cloudformation export NAME'

      # TODO: Add option for s3 exports

      option(:path,
        :long => '--export-path PATH',
        :description => 'Path to write export JSON file',
        :proc => lambda{|v| Chef::Config[:knife][:cloudformation][:export_path] = v }
      )

      def run
        if(Chef::Config[:knife][:cloudformation][:export_path])
          file_path = File.join(
            Chef::Config[:knife][:cloudformation][:export_path], "#{name_args.first}-#{Time.now.to_i}.json"
          )
        end
        ui.info "#{ui.color('Stack Export:', :bold)} #{name_args.first}"
        if(file_path)
          ui.info "  - Writing to: #{file_path}"
        else
          ui.info "  - Printing to console"
        end
        ui.confirm 'Perform export'
        exporter = KnifeCloudformation::Export.new(name_args.first, :aws_commons => aws)
        result = exporter.export
        if(file_path)
          File.open(file_path, 'w') do |file|
            file.puts _format_json(result)
          end
        else
          ui.info _format_json(result)
        end
        ui.info "#{ui.color('Stack export', :bold)} (#{name_args.first}): #{ui.color('complete', :green)}"
      end

    end
  end
end
