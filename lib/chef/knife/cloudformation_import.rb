require 'knife-cloudformation/cloudformation_base'

class Chef
  class Knife
    class CloudformationImport < Knife

      include KnifeCloudformation::KnifeBase

      banner 'knife cloudformation import NEW_STACK_NAME JSON_EXPORT_FILE'

      def run
        stack_name, json_file = name_args
        ui.info "#{ui.color('Stack Import', :bold)} (#{json_file})"
        if(File.exists?(json_file))
          stack = _from_json(File.read(json_file))
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

    end
  end
end
