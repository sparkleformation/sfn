require 'knife-cloudformation'

module KnifeCloudformation
  module Utils

    # Helper methods for string format modification
    module AnimalStrings

      # Camel case string
      #
      # @param string [String]
      # @return [String]
      def camel(string)
        string.to_s.split('_').map{|k| "#{k.slice(0,1).upcase}#{k.slice(1,k.length)}"}.join
      end

      # Snake case string
      #
      # @param string [String]
      # @return [Symbol]
      def snake(string)
        string.to_s.gsub(/([a-z])([A-Z])/, '\1_\2').downcase.to_sym
      end

    end

  end
end
