unless(defined?(Chef::Knife::CloudformationCreate))

  require 'bogo'
  Chef::Config[:knife][:cloudformation] = {
    :options => {},
    :create => {},
    :update => {}
  }

  require 'sfn'

  BOOLEAN_VALUES = [TrueClass, FalseClass]
  VALID_PREFIX = ['cloudformation', 'sparkleformation']


  Sfn::Config.constants.map do |konst|
    const = Sfn::Config.const_get(konst)
    if(const.is_a?(Class) && const.ancestors.include?(Bogo::Config))
      const
    end
  end.compact.sort_by(&:to_s).each do |klass|

    VALID_PREFIX.each do |prefix|

      klass_name = klass.name.split('::').last
      command_class = "#{prefix.capitalize}#{klass_name}"
      shorts = []

      knife_klass = Class.new(Chef::Knife)
      knife_klass.class_eval do

        include Bogo::AnimalStrings

        # Stub in names so knife will detect
        def self.name
          @name
        end

        def self.sfn_class
          @sfn_class
        end

        def name
          self.class.name
        end

        def run
          knife = Chef::Config[:knife]
          if(knife.respond_to?(:hash_dup))
            knife = knife.hash_dup
          end
          base = knife.to_smash
          keys = VALID_PREFIX.dup
          cmd_config = keys.unshift(keys.delete(snake(self.class.name.split('::').last).split('_').first)).map do |k|
            base[k]
          end.compact.first || {}
          cmd_config = cmd_config.to_smash
          reconfig = config.find_all do |k,v|
            !v.nil?
          end
          config = Smash[reconfig]
          cmd_config = cmd_config.deep_merge(config)
          self.class.sfn_class.new(cmd_config, name_args).execute!
        end

      end
      knife_klass.instance_variable_set(:@name, "Chef::Knife::#{command_class}")
      knife_klass.instance_variable_set(
        :@sfn_class,
        Bogo::Utility.constantize(klass.name.sub('Config', 'Command'))
      )
      knife_klass.banner "knife #{prefix} #{Bogo::Utility.snake(klass_name)}"

      Sfn::Config.attributes.merge(klass.attributes).sort_by(&:first).each do |name, info|
        next unless info[:description]
        short = name.chars.zip(name.chars.map(&:upcase)).flatten.detect do |c|
          !shorts.include?(c)
        end
        shorts << short
        bool = [info[:type]].compact.flatten.all?{|x| BOOLEAN_VALUES.include?(x) }
        if(bool)
          short = "-#{short}"
          long = "--[no-]#{name.tr('_', '-')}"
        else
          short = "-#{short} VALUE"
          long = "--#{name.tr('_', '-')} VALUE"
        end
        knife_klass.option(
          name.to_sym, {
            :short => short,
            :long => long,
            :boolean => bool,
            :default => info[:default],
            :description => info[:description]
          }
        )
      end
      # Set the class as a proper constant
      Chef::Knife.const_set(command_class, knife_klass)
      # Force knife to pick up as a subcommand
      Chef::Knife.inherited(knife_klass)
    end
  end
end
