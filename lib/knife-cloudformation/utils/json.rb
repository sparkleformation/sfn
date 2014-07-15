require 'knife-cloudformation'

module KnifeCloudformation
  module Utils

    # JSON helper methods
    module JSON

      # Attempt to load chef JSON compat helper
      #
      # @return [TrueClass, FalseClass] chef compat helper available
      def try_json_compat
        unless(@_json_loaded)
          begin
            require 'chef/json_compat'
          rescue
            require "#{ENV['RUBY_JSON_LIB'] || 'json'}"
          end
          @_json_loaded = true
        end
        defined?(Chef::JSONCompat)
      end

      # Convert to JSON
      #
      # @param thing [Object]
      # @return [String]
      def _to_json(thing)
        if(try_json_compat)
          Chef::JSONCompat.to_json(thing)
        else
          JSON.dump(thing)
        end
      end

      # Load JSON data
      #
      # @param thing [String]
      # @return [Object]
      def _from_json(thing)
        if(try_json_compat)
          Chef::JSONCompat.from_json(thing)
        else
          JSON.read(thing)
        end
      end

      # Format object into pretty JSON
      #
      # @param thing [Object]
      # @return [String]
      def _format_json(thing)
        thing = _from_json(thing) if thing.is_a?(String)
        if(try_json_compat)
          Chef::JSONCompat.to_json_pretty(thing)
        else
          JSON.pretty_generate(thing)
        end
      end

    end

  end
end
