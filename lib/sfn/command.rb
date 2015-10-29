require 'sfn'
require 'bogo-cli'

module Sfn
  class Command < Bogo::Cli::Command

    autoload :Create, 'sfn/command/create'
    autoload :Describe, 'sfn/command/describe'
    autoload :Destroy, 'sfn/command/destroy'
    autoload :Diff, 'sfn/command/diff'
    autoload :Events, 'sfn/command/events'
    autoload :Export, 'sfn/command/export'
    autoload :Import, 'sfn/command/import'
    autoload :Inspect, 'sfn/command/inspect'
    autoload :List, 'sfn/command/list'
    autoload :Print, 'sfn/command/print'
    autoload :Promote, 'sfn/command/promote'
    autoload :Update, 'sfn/command/update'
    autoload :Validate, 'sfn/command/validate'

    # Override to provide config file searching
    def initialize(cli_opts, args)
      unless(cli_opts['config'])
        discover_config(cli_opts)
      end
      super(cli_opts, args)
      run_callbacks_for(:after_config)
      run_callbacks_for("after_config_#{Bogo::Utility.snake(self.class.name)}")
    end

    # @return [Smash]
    def config
      memoize(:config) do
        super
      end
    end

    protected

    # Start with current working directory and traverse to root
    # looking for a `.sfn` configuration file
    #
    # @param opts [Slop]
    # @return [Slop]
    def discover_config(opts)
      cwd = Dir.pwd.split(File::SEPARATOR)
      until(cwd.empty? || File.exists?(cwd.push('.sfn').join(File::SEPARATOR)))
        cwd.pop(2)
      end
      if(opts.respond_to?(:fetch_option))
        opts.fetch_option('config').value = cwd.join(File::SEPARATOR) unless cwd.empty?
      else
        opts['config'] = cwd.join(File::SEPARATOR) unless cwd.empty?
      end
      opts
    end

    # @return [Class] attempt to return customized configuration class
    def config_class
      klass_name = self.class.name.split('::').last
      if(Sfn::Config.const_defined?(klass_name))
        Sfn::Config.const_get(klass_name)
      else
        super
      end
    end

  end
end
