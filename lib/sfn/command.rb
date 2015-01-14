require 'sfn'

class Sfn
  class Command < Bogo::Cli::Command

    autoload :CloudformationCreate, 'sfn/command/cloudformation_create'
    autoload :CloudformationDescribe, 'sfn/command/cloudformation_describe'
    autoload :CloudformationDestroy, 'sfn/command/cloudformation_destroy'
    autoload :CloudformationEvents, 'sfn/command/cloudformation_events'
    autoload :CloudformationExport, 'sfn/command/cloudformation_export'
    autoload :CloudformationImport, 'sfn/command/cloudformation_import'
    autoload :CloudformationInspect, 'sfn/command/cloudformation_inspect'
    autoload :CloudformationList, 'sfn/command/cloudformation_list'
    autoload :CloudformationPromote, 'sfn/command/cloudformation_promote'
    autoload :CloudformationUpdate, 'sfn/command/cloudformation_update'
    autoload :CloudformationValidate, 'sfn/command/cloudformation_validate'

  end
end
