require 'sfn'
require 'pathname'

module Sfn
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
      # @param directory [String] path to directory
      # @param opts [Hash] options
      # @option opts [Array<String>] :ignore_directories directory names
      # @option opts [String] :directories_name title for directories
      # @option opts [String] :files_name title for files
      # @option opts [String] :filter_prefix only return results matching filter
      # @return [String] file path
      def prompt_for_file(directory, opts={})
        file_list = Dir.glob(File.join(directory, '**', '**', '*')).find_all do |file|
          File.file?(file)
        end
        if(opts[:filter_prefix])
          file_list = file_list.find_all do |file|
            file.start_with?(options[:filter_prefix])
          end
        end
        directories = file_list.map do |file|
          File.dirname(file)
        end.uniq
        files = file_list.find_all do |path|
          path.sub(directory, '').split('/').size == 2
        end
        if(opts[:ignore_directories])
          directories.delete_if do |dir|
            opts[:ignore_directories].include?(File.basename(dir))
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
              valid[idx] = {:path => dir, :type => :directory}
              output << [idx, humanize_path_basename(dir)]
              idx += 1
            end
          end
          unless(files.empty?)
            output << ui.color("#{opts.fetch(:files_name, 'Files')}:", :bold)
            files.each do |file|
              valid[idx] = {:path => file, :type => :file}
              output << [idx, humanize_path_basename(file)]
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
          response = ui.ask_question('Enter selection: ').to_i
          unless(valid[response])
            ui.fatal 'How about using a real value'
            exit 1
          else
            entry = valid[response.to_i]
            if(entry[:type] == :directory)
              prompt_for_file(entry[:path], opts)
            elsif Pathname(entry[:path]).absolute?
              entry[:path]
            else
              "/#{entry[:path]}"
            end
          end
        end
      end

    end
  end
end
