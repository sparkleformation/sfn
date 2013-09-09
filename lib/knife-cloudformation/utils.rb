module KnifeCloudformation
  module Utils
    module JSON

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

      def _to_json(thing)
        if(try_json_compat)
          Chef::JSONCompat.to_json(thing)
        else
          JSON.dump(thing)
        end
      end

      def _from_json(thing)
        if(try_json_compat)
          Chef::JSONCompat.from_json(thing)
        else
          JSON.read(thing)
        end
      end

      def _format_json(thing)
        thing = _from_json(thing) if thing.is_a?(String)
        if(try_json_compat)
          Chef::JSONCompat.to_json_pretty(thing)
        else
          JSON.pretty_generate(thing)
        end
      end

    end

    module AnimalStrings

      def camel(string)
        string.to_s.split('_').map{|k| "#{k.slice(0,1).upcase}#{k.slice(1,k.length)}"}.join
      end

      def snake(string)
        string.to_s.gsub(/([a-z])([A-Z])/, '\1_\2').downcase.to_sym
      end

    end
  end
end
