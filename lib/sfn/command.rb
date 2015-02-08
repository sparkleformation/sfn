require 'sfn'
require 'bogo-cli'

module Sfn
  class Command < Bogo::Cli::Command

    autoload :Create, 'sfn/command/create'
    autoload :Describe, 'sfn/command/describe'
    autoload :Destroy, 'sfn/command/destroy'
    autoload :Events, 'sfn/command/events'
    autoload :Export, 'sfn/command/export'
    autoload :Import, 'sfn/command/import'
    autoload :Inspect, 'sfn/command/inspect'
    autoload :List, 'sfn/command/list'
    autoload :Promote, 'sfn/command/promote'
    autoload :Update, 'sfn/command/update'
    autoload :Validate, 'sfn/command/validate'

  end
end
