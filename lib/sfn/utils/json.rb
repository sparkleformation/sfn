require "sfn"

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

      alias_method :dump_json, :_to_json

      # Load JSON data
      #
      # @param thing [String]
      # @return [Object]
      def _from_json(thing)
        MultiJson.load(thing)
      end

      alias_method :load_json, :_from_json

      # Format object into pretty JSON
      #
      # @param thing [Object]
      # @return [String]
      def _format_json(thing)
        thing = _from_json(thing) if thing.is_a?(String)
        MultiJson.dump(thing, :pretty => true)
      end

      alias_method :format_json, :_format_json
    end
  end
end
