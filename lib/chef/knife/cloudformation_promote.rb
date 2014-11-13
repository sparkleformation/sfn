require 'knife-cloudformation'

class Chef
  class Knife
    class CloudformationPromote < Knife

      include KnifeCloudformation::Knife::Base

      banner 'knife cloudformation promote NEW_STACK_NAME DESTINATION'

      option(:accounts,
        :long => '--accounts-file PATH',
        :short => '-A PATH',
        :description => 'JSON account file',
        :proc => lambda{|v|
          Chef::Config[:knife][:cloudformation][:promote_accounts] = JSON.load(File.read(v))
        }
      )

      option(:storage_bucket,
        :long => '--exports-bucket NAME',
        :description => 'Bucket name containing the exports',
        :proc => lambda{|v| Chef::Config[:knife][:cloudformation][:promote_exports_bucket] = v }
      )

      option(:storage_prefix,
        :long => '--exports-prefix PREFIX',
        :description => 'Prefix of stack key',
        :proc => lambda{|v| Chef::Config[:knife][:cloudformation][:promote_exports_prefix] = v }
      )


      def _run
        stack_name, destination = name_args

      end

    end
  end
end
