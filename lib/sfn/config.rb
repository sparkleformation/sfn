require 'sfn'
require 'bogo-config'

module Sfn

  # Top level configuration
  class Config < Bogo::Config

    # Only values allowed designating bool type
    BOOLEAN_VALUES = [TrueClass, FalseClass]

    autoload :Create, 'sfn/config/create'
    autoload :Describe, 'sfn/config/describe'
    autoload :Destroy, 'sfn/config/destroy'
    autoload :Describe, 'sfn/config/describe'
    autoload :Events, 'sfn/config/events'
    autoload :Export, 'sfn/config/export'
    autoload :Import, 'sfn/config/import'
    autoload :Inspect, 'sfn/config/inspect'
    autoload :List, 'sfn/config/list'
    autoload :Promote, 'sfn/config/promote'
    autoload :Update, 'sfn/config/update'
    autoload :Validate, 'sfn/config/validate'

    attribute(
      :config, String,
      :description => 'Configuration file path'
    )

    attribute(
      :credentials, Smash,
      :coerce => proc{|v|
        case v
        when String
          Smash[v.split(',').map{|x| v.split(/[=:]/, 2)}]
        when Hash
          v.to_smash
        else
          v
        end
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
    attribute :describe, Describe, :coerce => proc{|v| Describe.new(v)}
    attribute :list, List, :coerce => proc{|v| List.new(v)}
    attribute :promote, Promote, :coerce => proc{|v| Promote.new(v)}
    attribute :validate, Validate, :coerce => proc{|v| Validate.new(v)}

    # Provide all options for config class (includes global configs)
    #
    # @param klass [Class]
    # @return [Smash]
    def self.options_for(klass)
      shorts = ['h'] # always reserve `-h` for help
      _options_for(klass, shorts)
    end

    # Provide options for config class
    #
    # @param klass [Class]
    # @param shorts [Array<String>]
    # @return [Smash]
    def self._options_for(klass, shorts)
      Smash[
        ([klass] + klass.ancestors).map do |a|
          if(a.ancestors.include?(Bogo::Config) && !a.attributes.empty?)
            a.attributes
          end
        end.compact.reverse.inject(Smash.new){|m, n| m.deep_merge(n)}.map do |name, info|
          next unless info[:description]
          short = name.chars.zip(name.chars.map(&:upcase)).flatten.detect do |c|
            !shorts.include?(c)
          end
          shorts << short
          info[:short] = short
          info[:long] = name.tr('_', '-')
          info[:boolean] = [info[:type]].compact.flatten.all?{|t| BOOLEAN_VALUES.include?(t)}
          [name, info]
        end.compact
      ]
    end

  end
end
