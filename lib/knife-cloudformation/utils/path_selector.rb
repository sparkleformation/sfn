require 'knife-cloudformation'

module KnifeCloudformation
  module Utils

    # Helper methods for path selection
    module PathSelector

      # Humanize the base name of path
      #
      # @param path [String]
      # @return [String]
      def humanize_path_basename(path)
        File.basename(path).sub(
          File.extname(path), ''
        ).split(/[-_]/).map(&:capitalize).join(' ')
      end

      # Prompt user for file selection
      #
      # @param directory [Fog::Storage::Directory] path to directory
      # @param opts [Hash] options
      # @option opts [Array<String>] :ignore_directories directory names
      # @option opts [String] :directories_name title for directories
      # @option opts [String] :files_name title for files
      # @option opts [String] :filter_prefix only return results matching filter
      # @return [String] file path
      def prompt_for_file(directory, opts={})
        if(opts[:filter_prefix])
          file_list = directory.files.find_all do |file|
            file.identity.start_with?(opts[:filter_prefix])
          end
        else
          file_list = directory.files
        end
        directories = file_list.find_all do |file|
          file.identity.split('/').size == 2
        end.group_by do |file|
          file.identity.split('/').first
        end.keys
        files = file_list.find_all do |file|
          file.identity.split('/').size == 1
        end
        if(opts[:ignore_directories])
          directories.delete_if do |dir|
            opts[:ignore_directories].include?(dir)
          end
        end
        if(directories.empty? && files.empty?)
          ui.fatal 'No formation paths discoverable!'
        else
          output = ['Please select an entry']
          output << '(or directory to list):' unless directories.empty?
          ui.info output.join(' ')
          output.clear
          idx = 1
          valid = {}
          unless(directories.empty?)
            output << ui.color("#{opts.fetch(:directories_name, 'Directories')}:", :bold)
            directories.each do |dir|
              valid[idx] = {:path => File.join(directory.identity, dir), :type => :directory}
              output << [idx, humanize_path_basename(dir)]
              idx += 1
            end
          end
          unless(files.empty?)
            output << ui.color("#{opts.fetch(:files_name, 'Files')}:", :bold)
            files.each do |file|
              valid[idx] = {:path => File.join(directory.identity, file.identity), :type => :file}
              output << [idx, humanize_path_basename(file.identity)]
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
              prompt_for_file(directory.collection.get(entry[:path]), opts)
            else
              "/#{entry[:path]}"
            end
          end
        end
      end

    end
  end
end
