require 'knife-cloudformation'

module KnifeCloudformation
  # Container for monkey patches
  module MonkeyPatch
    autoload :Stack, 'knife-cloudformation/monkey_patch/stack'
  end
end
