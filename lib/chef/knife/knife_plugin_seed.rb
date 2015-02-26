begin
  kcfn = Gem::Specification.find_by_name('knife-cloudformation')
  $stderr.puts "[WARN]: Deprecated gem detected: #{kcfn.name} [V: #{kcfn.version}]"
  $stderr.puts '[WARN]: Uninstall gem to prevent any conflicts (`gem uninstall knife-cloudformation -a`)'
rescue Gem::LoadError => e
  # ignore
end

unless(defined?(Chef::Knife::CloudformationCreate))

  require 'sfn'
  require 'bogo'

  Chef::Config[:knife][:cloudformation] = {
    :options => {},
    :create => {},
    :update => {}
  }
  Chef::Config[:knife][:sparkleformation] = Chef::Config[:knife][:cloudformation]

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

        # Properly load in configurations and execute command
        def run
          knife = Chef::Config[:knife]
          if(knife.respond_to?(:hash_dup))
            knife = knife.hash_dup
          end
          base = knife.to_smash
          keys = VALID_PREFIX.dup
          cmd_config = keys.unshift(keys.delete(snake(self.class.name.split('::').last).to_s.split('_').first)).map do |k|
            base[k]
          end.compact.first || {}
          cmd_config = cmd_config.to_smash
          reconfig = config.find_all do |k,v|
            !v.nil?
          end
          # Split up options provided multiple arguments
          reconfig.map! do |k,v|
            if(v.is_a?(String) && v.include?(','))
              v = v.split(',').map(&:strip)
            end
            [k,v]
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

      Sfn::Config.options_for(klass).each do |name, info|
        if(info[:boolean])
          short = "-#{info[:short]}"
          long = "--[no-]#{info[:long]}"
        else
          val = 'VALUE'
          if(info[:multiple])
            val << '[,VALUE]'
          end
          short = "-#{info[:short]} #{val}"
          long = "--#{info[:long]} #{val}"
        end
        knife_klass.option(
          name.to_sym, {
            :short => short,
            :long => long,
            :boolean => info[:boolean],
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
