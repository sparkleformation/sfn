require 'knife-cloudformation/version'
require 'miasma'

module KnifeCloudformation

  autoload :Provider, 'knife-cloudformation/provider'
  autoload :Cache, 'knife-cloudformation/cache'
  autoload :Export, 'knife-cloudformation/export'
  autoload :Utils, 'knife-cloudformation/utils'
  autoload :MonkeyPatch, 'knife-cloudformation/monkey_patch'
  autoload :Knife, 'knife-cloudformation/knife'

end

class Chef
  class Knife
    autoload :CloudformationCreate, 'chef/knife/cloudformation_create'
    autoload :CloudformationDescribe, 'chef/knife/cloudformation_describe'
    autoload :CloudformationDestroy, 'chef/knife/cloudformation_destroy'
    autoload :CloudformationEvents, 'chef/knife/cloudformation_events'
    autoload :CloudformationExport, 'chef/knife/cloudformation_export'
    autoload :CloudformationImport, 'chef/knife/cloudformation_import'
    autoload :CloudformationInspect, 'chef/knife/cloudformation_inspect'
    autoload :CloudformationList, 'chef/knife/cloudformation_list'
    autoload :CloudformationPromote, 'chef/knife/cloudformation_promote'
    autoload :CloudformationUpdate, 'chef/knife/cloudformation_update'
    autoload :CloudformationValidate, 'chef/knife/cloudformation_validate'
  end
end
