require 'sfn'

module Sfn
  class Config
    # Update command configuration
    class Update < Validate

      attribute(
        :print_only, [TrueClass, FalseClass],
        :description => 'Print the resulting stack template'
      )
      attribute(
        :apply_nesting, [TrueClass, FalseClass],
        :default => true,
        :description => 'Apply nested stacks. When disabled, stacks built in serial order.'
      )
      attribute(
        :apply_stack, String,
        :multiple => true,
        :description => 'Apply outputs from stack to input parameters'
      )

    end
  end
end
