require "sfn"

module Sfn
  class Callback
    # Support for AWS MFA
    class AwsMfa < Callback

      # Items to cache in local file
      SESSION_STORE_ITEMS = [
        :aws_sts_session_token,
        :aws_sts_session_access_key_id,
        :aws_sts_session_secret_access_key,
        :aws_sts_session_token_expires,
      ]

      # Prevent callback output to user
      def quiet
        true
      end

      # Inject MFA related configuration into
      # API provider credentials
      def after_config(*_)
        if enabled?
          load_stored_session
          api.connection.aws_sts_session_token_code = method(:prompt_for_code)
        end
      end

      # Store session token if available for
      # later use
      def after(*_)
        if enabled?
          if api.connection.aws_sts_session_token
            path = config.fetch(:aws_mfa, :cache_file, ".sfn-aws")
            FileUtils.touch(path)
            File.chmod(0600, path)
            values = load_stored_values(path)
            SESSION_STORE_ITEMS.map do |key|
              values[key] = api.connection.data[key]
            end
            File.open(path, "w") do |file|
              file.puts MultiJson.dump(values)
            end
          end
        end
      end

      alias_method :failed, :after

      # @return [TrueClass, FalseClass]
      def enabled?
        config.fetch(:aws_mfa, :status, "enabled").to_s == "enabled"
      end

      # Load stored configuration data into the api connection
      #
      # @return [TrueClass, FalseClass]
      def load_stored_session
        path = config.fetch(:aws_mfa, :cache_file, ".sfn-aws")
        if File.exists?(path)
          values = load_stored_values(path)
          SESSION_STORE_ITEMS.each do |key|
            api.connection.data[key] = values[key]
          end
          if values[:aws_sts_session_token_expires]
            begin
              api.connection.data[:aws_sts_session_token_expires] = Time.parse(values[:aws_sts_session_token_expires])
            rescue
            end
          end
          true
        else
          false
        end
      end

      # Load stored values
      #
      # @param path [String]
      # @return [Hash]
      def load_stored_values(path)
        begin
          if File.exists?(path)
            MultiJson.load(File.read(path)).to_smash
          else
            Smash.new
          end
        rescue MultiJson::ParseError
          Smash.new
        end
      end

      # Request MFA code from user
      #
      # @return [String]
      def prompt_for_code
        result = ui.ask "AWS MFA code", :valid => /^\d{6}$/
        result.strip
      end
    end
  end
end
