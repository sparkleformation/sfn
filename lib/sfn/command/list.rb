require 'sfn'

module Sfn
  class Command
    # List command
    class List < Command

      include Sfn::CommandModule::Base

      # Run the list command
      def execute!
        things_output(nil, get_list, nil)
      end

      # Get the list of stacks to display
      #
      # @return [Array<Hash>]
      def get_list
        get_things do
          provider.stacks.all.map do |stack|
            Smash.new(stack.attributes)
          end.sort do |x, y|
            if(y[:created].to_s.empty?)
              -1
            elsif(x[:created].to_s.empty?)
              1
            else
              Time.parse(y['created'].to_s) <=> Time.parse(x['created'].to_s)
            end
          end
        end
      end

      # @return [Array<String>] default attributes to display
      def default_attributes
        if(provider.connection.provider == :aws)
          %w(name created status template_description)
        else
          %w(name created status description)
        end
      end

    end
  end
end
