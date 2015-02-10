require 'sfn'

module Sfn
  module CommandModule
    # Base module for CLIs
    module Base

      # Instance methods for cloudformation command classes
      module InstanceMethods

        # @return [KnifeCloudformation::Provider]
        def provider
          memoize(:provider, :direct) do
            Sfn::Provider.new(
              :miasma => config[:credentials],
              :async => false,
              :fetch => false
            )
          end
        end

        # Write exception information if debug is enabled
        #
        # @param e [Exception]
        # @param args [String] extra strings to output
        def _debug(e, *args)
          if(config[:verbose])
            ui.fatal "Exception information: #{e.class}: #{e.message}"
            if(ENV['DEBUG'])
              puts "#{e.backtrace.join("\n")}\n"
              if(e.is_a?(Miasma::Error::ApiError))
                ui.fatal "Response body: #{e.response.body.to_s.inspect}"
              end
            end
            args.each do |string|
              ui.fatal string
            end
          end
        end

        # Get stack
        #
        # @param name [String] name of stack
        # @return [Miasma::Models::Orchestration::Stack]
        def stack(name)
          provider.stacks.get(name)
        end

        # @return [Array<String>] attributes to display
        def allowed_attributes
          opts.fetch(:attributes, config.fetch(:attributes, default_attributes))
        end

        # @return [Array<String>] default attributes to display
        def default_attributes
          %w(timestamp stack_name id)
        end

        # Check if attribute is allowed for display
        #
        # @param attr [String]
        # @return [TrueClass, FalseClass]
        def attribute_allowed?(attr)
          opts.fetch(:all_attributes, config[:all_attributes], allowed_attributes.include?(attr))
        end

        # Poll events on stack
        #
        # @param name [String] name of stack
        def poll_stack(name)
          provider.connection.stacks.reload
          retry_attempts = 0
          begin
            events = Sfn::Command::Events.new({:poll => true}, [name]).execute!
          rescue => e
            if(retry_attempts < config.fetch(:max_poll_retries, 5).to_i)
              retry_attempts += 1
              warn "Unexpected error encountered (#{e.class}: #{e}) Retrying [retry count: #{retry_attempts}]"
              sleep(1)
              retry
            else
              raise
            end
          end
        end

        # Wrapper for information retrieval. Provides consistent error
        # message for failures
        #
        # @param stack [String] stack name
        # @param message [String] failure message
        # @yield block to wrap error handling
        # @return [Object] result of yield
        def get_things(stack=nil, message=nil)
          begin
            yield
          rescue => e
            ui.fatal "#{message || 'Failed to retrieve information'}#{" for requested stack: #{stack}" if stack}"
            ui.fatal "Reason: #{e}"
            _debug(e)
            exit 1
          end
        end

        # Simple compat proxy method
        #
        # @return [Array<String>]
        def name_args
          arguments
        end

        # Fetches value from local configuration (#opts) and falls
        # back to global configuration (#options)
        #
        # @return [Object]
        def config
          memoize(:config) do
            options.deep_merge(opts)
          end
        end

      end

      class << self
        def included(klass)
          klass.instance_eval do

            include Sfn::CommandModule::Base::InstanceMethods
            include Sfn::Utils::JSON
            include Sfn::Utils::Output
            include Bogo::AnimalStrings
            include Bogo::Memoization

          end

        end
      end
    end

  end
end
