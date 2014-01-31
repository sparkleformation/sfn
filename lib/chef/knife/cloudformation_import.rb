require 'tempfile'
require 'knife-cloudformation/cloudformation_base'

class Chef
  class Knife
    class CloudformationImport < Knife

      include KnifeCloudformation::KnifeBase

      banner 'knife cloudformation import NEW_STACK_NAME [JSON_EXPORT_FILE]'

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

      def run
        stack_name, json_file = name_args
        ui.info "#{ui.color('Stack Import:', :bold)} #{stack_name}"
        unless(json_file)
          entries = [].tap do |_entries|
            _entries.push('s3') if Chef::Config[:knife][:cloudformation][:s3_bucket]
            _entries.push('fs') if Chef::Config[:knife][:cloudformation][:export_path]
          end
          if(entries.size > 1)
            valid = false
            until(valid)
              answer = ui.ask_question('Import via file system (fs) or bucket (s3)?', :default => 's3')
              valid = true if %w(s3 fs).include?(answer)
              entries = [answer]
            end
          elsif(entries.size < 1)
            ui.error 'No path or bucket set. Unable to perform dynamic lookup!'
            exit 1
          end
          case entries.first
          when 's3'
            bucket = Chef::Config[:knife][:cloudformation][:s3_bucket]
            prefix = Chef::Config[:knife][:cloudformation][:s3_prefix]
            json_file = s3_import_discovery(bucket, prefix)
          when 'fs'
            json_file = fs_import_discovery
          else
            ui.error "Unexpected dynamic discovery type encountered (#{entries.first})"
            exit 1
          end
        end
        if(File.exists?(json_file) || json_file.is_a?(IO))
          stack = _from_json(json_file.is_a?(IO) ? json_file.read : File.read(json_file))
          creator = Chef::Knife::CloudformationCreate.new
          creator.name_args = [stack_name]
          Chef::Config[:knife][:cloudformation][:template] = stack['template_body']
          Chef::Config[:knife][:cloudformation][:options] = Mash.new
          Chef::Config[:knife][:cloudformation][:options][:parameters] = Mash.new
          stack['parameters'].each do |k,v|
            Chef::Config[:knife][:cloudformation][:options][:parameters][k] = v
          end
          ui.info '  - Starting creation of import'
          creator.run
          ui.info "#{ui.color('Stack Import', :bold)} (#{json_file}): #{ui.color('complete', :green)}"
        else
          ui.error "Failed to locate JSON export file (#{json_file})"
          exit 1
        end
      end

      def s3_import_discovery(bucket, prefix)
        path = nil
        until(path)
          contents = s3_directory_contents(bucket, prefix)
          directories = contents[:directories]
          files = contents[:files]
          output = ['Please select the formation to import']
          output << '(or directory to list):' unless directories.empty?
          ui.info output.join(' ')
          output.clear
          idx = 1
          valid = {}

          unless(directories.empty?)
            output << ui.color('Directories:', :bold)
            directories.each do |path|
              valid[idx] = {:path => path, :type => :directory}
              output << [idx, File.basename(path).sub('.json', '').split(/[-_]/).map(&:capitalize).join(' ')]
              idx += 1
            end
          end
          unless(files.empty?)
            output << ui.color('Exports:', :bold)
            files.each do |path|
              valid[idx] = {:path => path, :type => :file}
              output << [idx, File.basename(path).sub('.rb', '')]
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
              puts "SET AS DIR"
              path = s3_import_discovery(bucket, entry[:path])
            else
              path = entry[:path]
            end
          end
        end
        if(path.is_a?(String))
          tmp_file = Tempfile.new(File.basename(path))
          tmp_file.write(aws.aws(:storage).get_object(bucket, path).body)
          tmp_file.flush
          tmp_file.rewind
          tmp_file
        else
          path
        end
      end

      def s3_directory_contents(bucket, prefix)
        prefix = prefix.dup
        prefix << '/' unless prefix.end_with?('/')
        result = aws.aws(:storage).get_bucket(bucket,
          :prefix => prefix, :delimiter => '/'
        ).body
        {}.tap do |content|
          content[:files] = result['Contents'].map do |content|
            content['Key']
          end
          content[:directories] = result['CommonPrefixes']
        end
      end


      def fs_import_discovery
      end

    end
  end
end
