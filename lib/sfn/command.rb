require "sfn"
require "bogo-cli"

module Sfn
  class Command < Bogo::Cli::Command
    include CommandModule::Callbacks

    autoload :Conf, 'sfn/command/conf'
    autoload :Create, 'sfn/command/create'
    autoload :Describe, 'sfn/command/describe'
    autoload :Destroy, 'sfn/command/destroy'
    autoload :Diff, 'sfn/command/diff'
    autoload :Events, 'sfn/command/events'
    autoload :Export, 'sfn/command/export'
    autoload :Graph, 'sfn/command/graph'
    autoload :Import, 'sfn/command/import'
    autoload :Init, 'sfn/command/init'
    autoload :Inspect, 'sfn/command/inspect'
    autoload :Lint, 'sfn/command/lint'
    autoload :List, 'sfn/command/list'
    autoload :Plan, 'sfn/command/plan'
    autoload :Print, 'sfn/command/print'
    autoload :Promote, 'sfn/command/promote'
    autoload :Update, 'sfn/command/update'
    autoload :Validate, 'sfn/command/validate'

    # Base name of configuration file
    CONFIG_BASE_NAME = ".sfn"

    # Supported configuration file extensions
    VALID_CONFIG_EXTENSIONS = [
      "",
      ".rb",
      ".json",
      ".yaml",
      ".yml",
      ".xml",
    ]

    # Override to provide config file searching
    def initialize(cli_opts, args)
      unless cli_opts["config"]
        discover_config(cli_opts)
      end
      unless ENV["DEBUG"]
        ENV["DEBUG"] = "true" if cli_opts[:debug]
      end
      super(cli_opts, args)
      load_api_provider_extensions!
      run_callbacks_for(:after_config)
      run_callbacks_for("after_config_#{Bogo::Utility.snake(self.class.name.split("::").last)}")
    end

    # @return [Smash]
    def config
      memoize(:config) do
        super
      end
    end

    protected

    # Load API provider specific overrides to customize behavior
    #
    # @return [TrueClass, FalseClass]
    def load_api_provider_extensions!
      if config.get(:credentials, :provider)
        base_ext = Bogo::Utility.camel(config.get(:credentials, :provider)).to_sym
        targ_ext = self.class.name.split("::").last
        if ApiProvider.constants.include?(base_ext)
          base_module = ApiProvider.const_get(base_ext)
          ui.debug "Loading core provider extensions via `#{base_module}`"
          extend base_module
          if base_module.constants.include?(targ_ext)
            targ_module = base_module.const_get(targ_ext)
            ui.debug "Loading targeted provider extensions via `#{targ_module}`"
            extend targ_module
          end
          true
        end
      end
    end

    # Start with current working directory and traverse to root
    # looking for a `.sfn` configuration file
    #
    # @param opts [Slop]
    # @return [Slop]
    def discover_config(opts)
      cwd = Dir.pwd.split(File::SEPARATOR)
      detected_path = ""
      until cwd.empty? || File.exists?(detected_path.to_s)
        detected_path = Dir.glob(
          (cwd + ["#{CONFIG_BASE_NAME}{#{VALID_CONFIG_EXTENSIONS.join(",")}}"]).join(
            File::SEPARATOR
          )
        ).first
        cwd.pop
      end
      if opts.respond_to?(:fetch_option)
        opts.fetch_option("config").value = detected_path if detected_path
      else
        opts["config"] = detected_path if detected_path
      end
      opts
    end

    # @return [Class] attempt to return customized configuration class
    def config_class
      klass_name = self.class.name.split("::").last
      if Sfn::Config.const_defined?(klass_name)
        Sfn::Config.const_get(klass_name)
      else
        super
      end
    end
  end
end
