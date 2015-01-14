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
          puts "<SparkleFormation>: #{msg}" if ENV['DEBUG']
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
