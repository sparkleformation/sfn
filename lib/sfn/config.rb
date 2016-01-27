require 'sfn'
require 'bogo-config'

module Sfn

  # Top level configuration
  class Config < Bogo::Config

    # Override attribute helper to detect Hash types and automatically
    # add type conversion for CLI provided values + description update
    #
    # @param name [String, Symbol] name of attribute
    # @param type [Class, Array<Class>] valid types
    # @param info [Hash] attribute information
    # @return [Hash]
    def self.attribute(name, type, info=Smash.new)
      if([type].flatten.any?{|t| t.ancestors.include?(Hash)})
        unless(info[:coerce])
          info[:coerce] = lambda do |v|
            case v
            when String
              Smash[
                v.split(',').map do |item_pair|
                  item_pair.split(/[=:]/, 2)
                end
              ]
            when Hash
              v.to_smash
            else
              v
            end
          end
          info[:description] ||= ''
          info[:description] << ' (Key:Value[,Key:Value,...])'
        end
      end
      super(name, type, info)
    end

    # Only values allowed designating bool type
    BOOLEAN_VALUES = [TrueClass, FalseClass]

    autoload :Conf, 'sfn/config/conf'
    autoload :Create, 'sfn/config/create'
    autoload :Describe, 'sfn/config/describe'
    autoload :Destroy, 'sfn/config/destroy'
    autoload :Describe, 'sfn/config/describe'
    autoload :Diff, 'sfn/config/diff'
    autoload :Events, 'sfn/config/events'
    autoload :Export, 'sfn/config/export'
    autoload :Import, 'sfn/config/import'
    autoload :Init, 'sfn/config/init'
    autoload :Inspect, 'sfn/config/inspect'
    autoload :List, 'sfn/config/list'
    autoload :Print, 'sfn/config/print'
    autoload :Promote, 'sfn/config/promote'
    autoload :Update, 'sfn/config/update'
    autoload :Validate, 'sfn/config/validate'

    attribute(
      :config, String,
      :description => 'Configuration file path',
      :short_flag => 'c'
    )

    attribute(
      :credentials, Smash,
      :description => 'Provider credentials',
      :short_flag => 'C'
    )
    attribute(
      :ignore_parameters, String,
      :multiple => true,
      :description => 'Parameters to ignore during modifications',
      :short_flag => 'i'
    )
    attribute(
      :interactive_parameters, [TrueClass, FalseClass],
      :default => true,
      :description => 'Prompt for template parameters',
      :short_flag => 'I'
    )
    attribute(
      :poll, [TrueClass, FalseClass],
      :default => true,
      :description => 'Poll stack events on modification actions',
      :short_flag => 'p'
    )
    attribute(
      :defaults, [TrueClass, FalseClass],
      :description => 'Automatically accept default values',
      :short_flag => 'd'
    )
    attribute(
      :yes, [TrueClass, FalseClass],
      :description => 'Automatically accept any requests for confirmation',
      :short_flag => 'y'
    )
    attribute(
      :debug, [TrueClass, FalseClass],
      :description => 'Enable debug output',
      :short_flag => 'u'
    )

    attribute :conf, Conf, :coerce => proc{|v| Conf.new(v)}
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
          short = info[:short_flag]
          if(!short.to_s.empty? && shorts.include?(short))
            raise ArgumentError.new "Short flag already in use! (`#{short}` not available for `#{klass}`)"
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
