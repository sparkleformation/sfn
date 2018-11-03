module Sfn
  class Error < StandardError
    # @return [Integer] exit code to report
    attr_reader :exit_code
    # @return [Exception, nil] original exception
    attr_reader :original

    # Exit code used when no custom code provided
    DEFAULT_EXIT_CODE = 1

    def self.exit_code(c=nil)
      if c || !defined?(@exit_code)
        @exit_code = c.to_i != 0 ? c : DEFAULT_EXIT_CODE
      end
      @exit_code
    end

    def self.error_msg(m=nil)
      if m || !defined?(@error_msg)
        @error_msg = m
      end
      @error_msg
    end

    def initialize(*args)
      opts = args.detect{ |a| a.is_a?(Hash) } || {}
      opts = opts.to_smash
      msg = args.first.is_a?(String) ? args.first : self.class.error_msg
      super(msg)
      @exit_code = opts.fetch(:exit_code, self.class.exit_code).to_i
      if opts[:original]
        if opts[:original].is_a?(Exception)
          @original = opts[:original]
        else
          raise TypeError.new "Expected `Exception` type in `:original` " \
            "option but received `#{opts[:original].class}`"
        end
      end
    end

    class InteractionDisabled < Error
      error_msg "Interactive prompting is disabled"
      exit_code 2
    end

    class StackNotFound < Error
      error_msg "Failed to locate requested stack"
      exit_code 3
    end

    class StackPlanNotFound < Error
      error_msg "Failed to locate requested stack plan"
      exit_code 4
    end

    class StackStateIncomplete < Error
      error_msg "Stack did not reach a successful completion state"
      exit_code 5
    end
  end
end
