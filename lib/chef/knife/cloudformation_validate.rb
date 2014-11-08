require 'pathname'
require 'sparkle_formation'
require 'knife-cloudformation'

class Chef
  class Knife
    # Cloudformation validate command
    class CloudformationValidate < Knife

      include KnifeCloudformation::Knife::Base
      include KnifeCloudformation::Knife::Template

      banner 'knife cloudformation validate'

      def run
        file = load_template_file
        ui.info "#{ui.color('Cloud Formation Validation: ', :bold)} #{Chef::Config[:knife][:cloudformation][:file].sub(Dir.pwd, '').sub(%r{^/}, '')}"
        file = translate_template(file)
        begin
          result = provider.stacks.build(
            :name => 'validation-stack',
            :template => file
          ).validate
          ui.info ui.color('  -> VALID', :bold, :green)
        rescue => e
          ui.info ui.color('  -> INVALID', :bold, :red)
          ui.fatal e.message
          failed = true
        end
      end

    end
  end
end
