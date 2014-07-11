require 'knife-cloudformation/version'

module KnifeCloudformation

  autoload :Provider, 'knife-cloudformation/provider'
  autoload :Cache, 'knife-cloudformation/cache'
  autoload :Export, 'knife-cloudformation/export'
  autoload :KnifeBase, 'knife-cloudformation/cloudformation_base'
  autoload :Utils, 'knife-cloudformation/utils'
  autoload :MonkeyPatch, 'knife-cloudformation/monkey_patch'

end
