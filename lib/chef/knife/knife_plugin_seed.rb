unless(defined?(Chef::Knife::CloudformationCreate))
  require 'sfn'

  BOOLEAN_VALUES = [TrueClass, FalseClass]

  Sfn::Config.constants.map do |konst|
    const = Sfn::Config.const_get(konst)
    if(const.is_a?(Class) && const.ancestors.include?(Bogo::Config))
      const
    end
  end.compact.sort_by(&:to_s).each do |klass|

    klass_name = klass.name.split('::').last
    command_class = "Cloudformation#{klass_name}"
    shorts = []

    knife_klass = Class.new(Chef::Knife)
    knife_klass.class_eval do
      # Stub in names so knife will detect
      def self.name
        @name
      end

      def name
        self.class.name
      end

      def run
        puts "WE SHOULD DO STUFF!"
      end

    end
    knife_klass.instance_variable_set(:@name, "Chef::Knife::#{command_class}")
    knife_klass.banner "knife cloudformation #{Bogo::Utility.snake(klass_name)}"

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
