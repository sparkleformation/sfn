require 'sfn'

module Sfn

  # Top level configuration
  class Config < Bogo::Config

    autoload :Create, 'sfn/config/create'
    autoload :Describe, 'sfn/config/describe'
    autoload :Destroy, 'sfn/config/destroy'
    autoload :Events, 'sfn/config/events'
    autoload :Export, 'sfn/config/export'
    autoload :Import, 'sfn/config/import'
    autoload :Inspect, 'sfn/config/inspect'
    autoload :List, 'sfn/config/list'
    autoload :Promote, 'sfn/config/promote'
    autoload :Update, 'sfn/config/update'
    autoload :Validate, 'sfn/config/validate'

    attribute(
      :credentials, Smash,
      :coerce => proc{|v|
        v = Smash[v.split(',').map{|x| v.split('=')}] if v.is_a?(String)
        v.to_smash
      },
      :description => 'Provider credentials'
    )
    attribute(
      :ignore_parameters, String,
      :multiple => true,
      :description => 'Parameters to ignore during modifications'
    )
    attribute(
      :interactive_parameters, [TrueClass, FalseClass],
      :default => true,
      :description => 'Prompt for template parameters'
    )
    attribute(
      :poll, [TrueClass, FalseClass],
      :default => true,
      :description => 'Poll stack events on modification actions'
    )
    attribute(
      :defaults, [TrueClass, FalseClass],
      :description => 'Automatically accept default values'
    )
    attribute(
      :yes, [TrueClass, FalseClass],
      :description => 'Automatically accept any requests for confirmation'
    )

    attribute :create, Create, :coerce => proc{|v| Create.new(v)}
    attribute :update, Update, :coerce => proc{|v| Update.new(v)}
    attribute :destroy, Destroy, :coerce => proc{|v| Destroy.new(v)}
    attribute :events, Events, :coerce => proc{|v| Events.new(v)}
    attribute :export, Export, :coerce => proc{|v| Export.new(v)}
    attribute :import, Import, :coerce => proc{|v| Import.new(v)}
    attribute :inspect, Inspect, :coerce => proc{|v| Inpsect.new(v)}
    attribute :list, List, :coerce => proc{|v| List.new(v)}
    attribute :promote, PromoteConfig, :coerce => proc{|v| Promote.new(v)}
    attribute :validate, ValidateConfig, :coerce => proc{|v| Validate.new(v)}

  end
end
