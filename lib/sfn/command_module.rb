require 'sfn'

module Sfn
  module CommandModule
    autoload :Base, 'sfn/command_module/base'
    autoload :Stack, 'sfn/command_module/stack'
    autoload :Template, 'sfn/command_module/template'
  end
end
