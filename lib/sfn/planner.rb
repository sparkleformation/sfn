require 'sfn'

module Sfn
  # Interface for generating plan report
  class Planner

    autoload :Aws, 'sfn/planner/aws'

    # @return [Bogo::Ui]
    attr_reader :ui
    # @return [Smash]
    attr_reader :config
    # @return [Array<String>] CLI arguments
    attr_reader :arguments
    # @return [Miasma::Models::Orchestration::Stack] existing remote stack
    attr_reader :origin_stack

    # Create a new planner instance
    #
    # @param ui [Bogo::Ui]
    # @param config [Smash]
    # @param arguments [Array<String>]
    # @param stack [Miasma::Models::Orchestration::Stack]
    #
    # @return [self]
    def initialize(ui, config, arguments, stack)
      @ui = ui
      @config = config
      @arguments = arguments
      @origin_stack = stack
    end

    # Generate update report
    #
    # @param template [Hash] updated template
    # @param parameters [Hash] runtime parameters for update
    #
    # @return [Hash] report
    def generate_plan(template, parameters)
      raise NotImplementedError
    end

  end
end
