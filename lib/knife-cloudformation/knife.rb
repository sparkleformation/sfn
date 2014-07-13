require 'knife-cloudformation'

module KnifeCloudformation
  module Knife
    autoload :Base, 'knife-cloudformation/knife/base'
    autoload :Stack, 'knife-cloudformation/knife/stack'
    autoload :Template, 'knife-cloudformation/knife/template'
  end
end
