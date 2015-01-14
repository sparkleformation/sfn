require 'sfn'

module Sfn
  module Utils

    # JSON helper methods
    module JSON

      # Convert to JSON
      #
      # @param thing [Object]
      # @return [String]
      def _to_json(thing)
        MultiJson.dump(thing)
      end

      # Load JSON data
      #
      # @param thing [String]
      # @return [Object]
      def _from_json(thing)
        MultiJson.load(thing)
      end

      # Format object into pretty JSON
      #
      # @param thing [Object]
      # @return [String]
      def _format_json(thing)
        thing = _from_json(thing) if thing.is_a?(String)
        MultiJson.dump(thing, :pretty => true)
      end

    end

  end
end
