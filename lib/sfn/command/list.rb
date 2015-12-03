require 'sfn'

module Sfn
  class Command
    # List command
    class List < Command

      include Sfn::CommandModule::Base

      # Run the list command
      def execute!
        ui.table(self) do
          table(:border => false) do
            stacks = get_stacks
            row(:header => true) do
              allowed_attributes.each do |attr|
                column attr.split('_').map(&:capitalize).join(' '), :width => (stacks.map{|s| s[attr].to_s.length}.max || 20) + 2
              end
            end
            get_stacks.each do |stack|
              row do
                allowed_attributes.each do |attr|
                  column stack[attr]
                end
              end
            end
          end
        end.display
      end

      # Get the list of stacks to display
      #
      # @return [Array<Hash>]
      def get_stacks
        provider.stacks.all.map do |stack|
          Smash.new(stack.attributes)
        end.sort do |x, y|
          if(y[:created].to_s.empty?)
            -1
          elsif(x[:created].to_s.empty?)
            1
          else
            Time.parse(x[:created].to_s) <=> Time.parse(y[:created].to_s)
          end
        end
      end

      # @return [Array<String>] default attributes to display
      def default_attributes
        if(provider.connection.provider == :aws)
          %w(name created updated status template_description)
        else
          %w(name created updated status description)
        end
      end

    end
  end
end
