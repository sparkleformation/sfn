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

    module Ssher
      def remote_file_contents(address, user, path, ssh_opts={})
        require 'net/sftp'
        content = ''
        ssh_session = Net::SSH.start(address, user, ssh_opts)
        con = Net::SFTP::Session.new(ssh_session)
        con.loop{ con.opening? }
        f_handle = con.open!(path)
        data = ''
        count = 0
        while(data)
          data = nil
          request = con.read(f_handle, count, 1024) do |response|
            unless(response.eof?)
              if(response.ok?)
                count += 1024
                content << response[:data]
                data = true
              end
            end
          end
          request.wait
        end
        con.close!(f_handle)
        con.close_channel
        ssh_session.close
        content.empty? ? nil : content
      end
    end
  end
end
