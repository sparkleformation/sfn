require 'sfn'

module Sfn
  # Container for monkey patches
  module MonkeyPatch
    autoload :Stack, 'sfn/monkey_patch/stack'
  end
end
