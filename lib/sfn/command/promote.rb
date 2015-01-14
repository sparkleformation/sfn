require 'sfn'

module Sfn
  class Command
    # Promote command
    class Promote < Command

      include Sfn::CommandModule::Base

      def execute!
        raise NotImplementedError
        stack_name, destination = name_args
      end

    end
  end
end
