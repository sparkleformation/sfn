require 'sfn'

module Sfn
  # Interface for injecting custom functionality
  class Callback

    autoload :AwsMfa, 'sfn/callback/aws_mfa'
    autoload :StackPolicy, 'sfn/callback/stack_policy'

    # @return [Bogo::Ui]
    attr_reader :ui
    # @return [Smash]
    attr_reader :config
    # @return [Array<String>] CLI arguments
    attr_reader :arguments
    # @return [Miasma::Models::Orchestration] remote API
    attr_reader :api

    # Create a new callback instance
    #
    # @param ui [Bogo::Ui]
    # @param config [Smash] configuration hash
    # @param arguments [Array<String>] arguments from the CLI
    # @param api [Provider] API connection
    #
    # @return [self]
    def initialize(ui, config, arguments, api)
      @ui = ui
      @config = config
      @arguments = arguments
      @api = api
    end

    # Wrap action within status text
    #
    # @param msg [String] action text
    # @yieldblock action to perform
    # @return [Object] result of yield
    def run_action(msg)
      ui.info("#{msg}... ", :nonewline)
      begin
        result = yield
        ui.puts ui.color('complete!', :green, :bold)
        result
      rescue => e
        ui.puts ui.color('error!', :red, :bold)
        ui.error "Reason - #{e}"
        raise
      end
    end

  end
end
