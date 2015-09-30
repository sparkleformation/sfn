require 'sfn'

module Sfn
  class Command
    class Destroy < Command

      include Sfn::CommandModule::Base

      # Run the stack destruction action
      def execute!
        stacks = name_args.sort
        plural = 's' if stacks.size > 1
        globs = stacks.find_all do |s|
          s !~ /^[a-zA-Z0-9-]+$/
        end
        unless(globs.empty?)
          glob_stacks = provider.connection.stacks.all.find_all do |remote_stack|
            globs.detect do |glob|
              File.fnmatch(glob, remote_stack.name)
            end
          end
          stacks += glob_stacks.map(&:name)
          stacks -= globs
          stacks.sort!
        end
        ui.warn "Destroying Stack#{plural}: #{ui.color(stacks.join(', '), :bold)}"
        ui.confirm "Destroy listed stack#{plural}?"
        stacks.each do |stack_name|
          stack = provider.connection.stacks.get(stack_name)
          if(stack)
            nested_stack_cleanup!(stack)
            stack.destroy
            ui.info "Destroy request complete for stack: #{ui.color(stack_name, :red)}"
          else
            ui.warn "Failed to locate requested stack: #{ui.color(stack_name, :bold)}"
          end
        end
        if(config[:poll])
          if(stacks.size == 1)
            poll_stack(stacks.first)
          else
            ui.error "Stack polling is not available when multiple stack deletion is requested!"
          end
        end
        ui.info "  -> Destroyed SparkleFormation#{plural}: #{ui.color(stacks.join(', '), :bold, :red)}"
      end

      # Cleanup persisted templates if nested stack resources are included
      def nested_stack_cleanup!(stack)
        nest_stacks = stack.template.fetch('Resources', {}).values.find_all do |resource|
          resource['Type'] == 'AWS::CloudFormation::Stack'
        end.each do |resource|
          url = resource['Properties']['TemplateURL']
          if(url)
            _, bucket_name, path = URI.parse(url).path.split('/', 3)
            bucket = provider.connection.api_for(:storage).buckets.get(bucket_name)
            if(bucket)
              file = bucket.files.get(path)
              if(file)
                file.destroy
                ui.info "Deleted nested stack template! (Bucket: #{bucket_name} Template: #{path})"
              else
                ui.warn "Failed to locate template file within bucket for deletion! (#{path})"
              end
            else
              ui.warn "Failed to locate bucket containing template file for deletion! (#{bucket_name})"
            end
          end
        end
      end

    end
  end
end
