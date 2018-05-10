require "sfn"

module Sfn
  module CommandModule
    autoload :Base, "sfn/command_module/base"
    autoload :Callbacks, "sfn/command_module/callbacks"
    autoload :Stack, "sfn/command_module/stack"
    autoload :Template, "sfn/command_module/template"
  end
end
