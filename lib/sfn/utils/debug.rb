require 'sfn'

module Sfn
  module Utils
    # Debug helpers
    module Debug
      # Output helpers
      module Output
        # Write debug message
        #
        # @param msg [String]
        def debug(msg)
          if ENV['DEBUG'] || (respond_to?(:config) && config[:debug])
            puts "<sfn - debug>: #{msg}"
          end
        end
      end

      class << self
        # Load module into class
        #
        # @param klass [Class]
        def included(klass)
          klass.class_eval do
            include Output
            extend Output
          end
        end
      end
    end
  end
end
