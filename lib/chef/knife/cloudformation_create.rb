require 'sparkle_formation'
require 'pathname'
require 'knife-cloudformation/cloudformation_base'

class Chef
  class Knife
    class CloudformationCreate < Knife

      include KnifeCloudformation::KnifeBase

      banner 'knife cloudformation create NAME'

      module Options
        class << self
          def included(klass)
            klass.class_eval do

              attr_accessor :action_type

              option(:parameter,
                :short => '-p KEY:VALUE',
                :long => '--parameter KEY:VALUE',
                :description => 'Set parameter. Can be used multiple times.',
                :proc => lambda {|val|
                  parts = val.split(':')
                  key = parts.first
                  value = parts[1, parts.size].join(':')
                  Chef::Config[:knife][:cloudformation][:options][:parameters] ||= Mash.new
                  Chef::Config[:knife][:cloudformation][:options][:parameters][key] = value
                }
              )
              option(:timeout,
                :short => '-t MIN',
                :long => '--timeout MIN',
                :description => 'Set timeout for stack creation',
                :proc => lambda {|val|
                  Chef::Config[:knife][:cloudformation][:options][:timeout_in_minutes] = val
                }
              )
              option(:rollback,
                :short => '-R',
                :long => '--[no]-rollback',
                :description => 'Rollback on stack creation failure',
                :boolean => true,
                :default => true,
                :proc => lambda {|val| Chef::Config[:knife][:cloudformation][:options][:disable_rollback] = !val }
              )
              option(:capability,
                :short => '-C CAPABILITY',
                :long => '--capability CAPABILITY',
                :description => 'Specify allowed capabilities. Can be used multiple times.',
                :proc => lambda {|val|
                  Chef::Config[:knife][:cloudformation][:options][:capabilities] ||= []
                  Chef::Config[:knife][:cloudformation][:options][:capabilities].push(val).uniq!
                }
              )
              option(:processing,
                :long => '--[no-]processing',
                :description => 'Call the unicorns and explode the glitter bombs',
                :boolean => true,
                :default => false,
                :proc => lambda {|val| Chef::Config[:knife][:cloudformation][:processing] = val }
              )
              option(:polling,
                :long => '--[no-]poll',
                :description => 'Enable stack event polling.',
                :boolean => true,
                :default => true,
                :proc => lambda {|val| Chef::Config[:knife][:cloudformation][:poll] = val }
              )
              option(:notifications,
                :long => '--notification ARN',
                :description => 'Add notification ARN. Can be used multiple times.',
                :proc => lambda {|val|
                  Chef::Config[:knife][:cloudformation][:options][:notification_ARNs] ||= []
                  Chef::Config[:knife][:cloudformation][:options][:notification_ARNs].push(val).uniq!
                }
              )
              option(:file,
                :short => '-f PATH',
                :long => '--file PATH',
                :description => 'Path to Cloud Formation to process',
                :proc => lambda {|val|
                  Chef::Config[:knife][:cloudformation][:file] = val
                }
              )
              option(:interactive_parameters,
                :long => '--[no-]parameter-prompts',
                :boolean => true,
                :default => true,
                :description => 'Do not prompt for input on dynamic parameters',
                :default => true
              )
              option(:print_only,
                :long => '--print-only',
                :description => 'Print template and exit'
              )
              option(:base_directory,
                :long => '--cloudformation-directory PATH',
                :description => 'Path to cloudformation directory',
                :proc => lambda {|val| Chef::Config[:knife][:cloudformation][:base_directory] = val}
              )
              option(:no_base_directory,
                :long => '--no-cloudformation-directory',
                :description => 'Unset any value used for cloudformation path',
                :proc => lambda {|*val| Chef::Config[:knife][:cloudformation][:base_directory] = nil}
              )

              %w(rollback polling interactive_parameters).each do |key|
                if(Chef::Config[:knife][:cloudformation][key].nil?)
                  Chef::Config[:knife][:cloudformation][key] = true
                end
              end
            end
          end
        end
      end

      include Options

      def run
        @action_type = self.class.name.split('::').last.sub('Cloudformation', '').upcase
        name = name_args.first
        unless(name)
          ui.fatal "Formation name must be specified!"
          exit 1
        end

        unless(Chef::Config[:knife][:cloudformation][:template])
          set_paths_and_discover_file!
          unless(File.exists?(Chef::Config[:knife][:cloudformation][:file].to_s))
            ui.fatal "Invalid formation file path provided: #{Chef::Config[:knife][:cloudformation][:file]}"
            exit 1
          end
        end

        if(Chef::Config[:knife][:cloudformation][:template])
          file = Chef::Config[:knife][:cloudformation][:template]
        elsif(Chef::Config[:knife][:cloudformation][:processing])
          file = SparkleFormation.compile(Chef::Config[:knife][:cloudformation][:file])
        else
          file = _from_json(File.read(Chef::Config[:knife][:cloudformation][:file]))
        end
        if(config[:print_only])
          ui.warn 'Print only requested'
          ui.info _format_json(file)
          exit 1
        end
        ui.info "#{ui.color('Cloud Formation: ', :bold)} #{ui.color(action_type, :green)}"
        stack_info = "#{ui.color('Name:', :bold)} #{name}"
        if(Chef::Config[:knife][:cloudformation][:path])
          stack_info << " #{ui.color('Path:', :bold)} #{Chef::Config[:knife][:cloudformation][:file]}"
          if(Chef::Config[:knife][:cloudformation][:disable_processing])
            stack_info << " #{ui.color('(not pre-processed)', :yellow)}"
          end
        end
        ui.info "  -> #{stack_info}"
        populate_parameters!(file)
        stack_def = KnifeCloudformation::AwsCommons::Stack.build_stack_definition(file, Chef::Config[:knife][:cloudformation][:options])
        aws.create_stack(name, stack_def)
        if(Chef::Config[:knife][:cloudformation][:poll])
          poll_stack(name)
          if(stack(name).success?)
            ui.info "Stack #{action_type} complete: #{ui.color('SUCCESS', :green)}"
            knife_output = Chef::Knife::CloudformationDescribe.new
            knife_output.name_args.push(name)
            knife_output.config[:outputs] = true
            knife_output.run
          else
            ui.fatal "#{action_type} of new stack #{ui.color(name, :bold)}: #{ui.color('FAILED', :red, :bold)}"
            ui.info ""
            knife_inspect = Chef::Knife::CloudformationInspect.new
            knife_inspect.name_args.push(name)
            knife_inspect.config[:instance_failure] = true
            knife_inspect.run
            exit 1
          end
        else
          ui.warn 'Stack state polling has been disabled.'
          ui.info "Stack creation initialized for #{ui.color(name, :green)}"
        end
      end

      def populate_parameters!(stack)
        if(Chef::Config[:knife][:cloudformation][:interactive_parameters])
          if(stack['Parameters'])
            Chef::Config[:knife][:cloudformation][:options][:parameters] ||= Mash.new
            stack['Parameters'].each do |k,v|
              next if Chef::Config[:knife][:cloudformation][:options][:parameters][k]
              valid = false
              until(valid)
                default = Chef::Config[:knife][:cloudformation][:options][:parameters][k] || v['Default']
                answer = ui.ask_question("#{k.split(/([A-Z]+[^A-Z]*)/).find_all{|s|!s.empty?}.join(' ')}: ", :default => default)
                validation = KnifeCloudformation::AwsCommons::Stack::ParameterValidator.validate(answer, v)
                if(validation == true)
                  Chef::Config[:knife][:cloudformation][:options][:parameters][k] = answer
                  valid = true
                else
                  validation.each do |validation_error|
                    ui.error validation_error.last
                  end
                end
              end
            end
          end
        end
      end

      private

      def set_paths_and_discover_file!
        if(Chef::Config[:knife][:cloudformation][:base_directory])
          SparkleFormation.components_path = File.join(
            Chef::Config[:knife][:cloudformation][:base_directory], 'components'
          )
          SparkleFormation.dynamics_path = File.join(
            Chef::Config[:knife][:cloudformation][:base_directory], 'dynamics'
          )
        end
        unless(Chef::Config[:knife][:cloudformation][:file])
          Chef::Config[:knife][:cloudformation][:file] = prompt_for_file(
            Chef::Config[:knife][:cloudformation][:base_directory] || File.join(Dir.pwd, 'cloudformation')
          )
        else
          unless(Pathname(Chef::Config[:knife][:cloudformation][:file]).absolute?)
            Chef::Config[:knife][:cloudformation][:file] = File.join(
              Chef::Config[:knife][:cloudformation][:base_directory] || File.join(Dir.pwd, 'cloudformation'),
              Chef::Config[:knife][:cloudformation][:file]
            )
          end
        end
      end

      def prompt_for_file(dir)
        directory = Dir.new(dir)
        directories = directory.map do |d|
          if(!d.start_with?('.') && !%w(dynamics components).include?(d) && File.directory?(path = File.join(dir, d)))
            path
          end
        end.compact.sort
        files = directory.map do |f|
          if(!f.start_with?('.') && File.file?(path = File.join(dir, f)))
            path
          end
        end.compact.sort
        if(directories.empty? && files.empty?)
          ui.fatal 'No formation paths discoverable!'
        else
          output = ['Please select the formation to create']
          output << '(or directory to list):' unless directories.empty?
          ui.info output.join(' ')
          output.clear
          idx = 1
          valid = {}
          unless(directories.empty?)
            output << ui.color('Directories:', :bold)
            directories.each do |path|
              valid[idx] = {:path => path, :type => :directory}
              output << [idx, "#{File.basename(path).sub('.rb', '').split(/[-_]/).map(&:capitalize).join(' ')}"]
              idx += 1
            end
          end
          unless(files.empty?)
            output << ui.color('Templates:', :bold)
            files.each do |path|
              valid[idx] = {:path => path, :type => :file}
              output << [idx, "#{File.basename(path).sub('.rb', '').split(/[-_]/).map(&:capitalize).join(' ')}"]
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
              prompt_for_file(entry[:path])
            else
              Chef::Config[:knife][:cloudformation][:file] = entry[:path]
            end
          end
        end
      end

    end
  end
end
