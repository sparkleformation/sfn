require 'sfn'

module Sfn
  module ApiProvider

    module Google

      # Disable remote template storage
      def store_template(*_)
      end

      # No formatting required on stack results
      def format_nested_stack_results(*_)
        {}
      end

      # Set parameters into parent resource properites
      def populate_parameters!(template, opts={})
        result = super
        result.each_pair do |key, value|
          if(template.parent)
            template.parent.compile.resources.set!(template.name).properties.set!(key, value)
          else
            template.compile.resources.set!(template.name).properties.set!(key, value)
          end
        end
        {}
      end

    end

  end
end
