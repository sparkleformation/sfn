require 'chef/knife'
require 'knife-cloudformation'

module KnifeCloudformation
  # Base to build cloudformation related knife commands
  module KnifeBase

    # Instance methods for cloudformation command classes
    module InstanceMethods

      # @return [KnifeCloudformation::Provider]
      def provider
        self.class.provider
      end

      # Write exception information if debug is enabled
      #
      # @param e [Exception]
      # @param args [String] extra strings to output
      def _debug(e, *args)
        if(ENV['DEBUG'])
          ui.fatal "Exception information: #{e.class}: #{e}\n#{e.backtrace.join("\n")}\n"
          args.each do |string|
            ui.fatal string
          end
        end
      end

      # Get stack
      #
      # @param name [String] name of stack
      # @return [Fog::Orchestration::Stack]
      def stack(name)
        provider.stack(name)
      end

      # @return [Array<String>] attributes to display
      def allowed_attributes
        Chef::Config[:knife][:cloudformation][:attributes] || default_attributes
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
        config[:all_attributes] || allowed_attributes.include?(attr)
      end

      # Poll events on stack
      #
      # @param name [String] name of stack
      def poll_stack(name)
        knife_events = Chef::Knife::CloudformationEvents.new
        knife_events.name_args.push(name)
        Chef::Config[:knife][:cloudformation][:poll] = true
        knife_events.run
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

      # Disable chef configuration. Let the dep loader do that for us
      # so it doesn't squash config values set via options
      def configure_chef
        true
      end

    end

    module ClassMethods

      # Configure chef here so we can have config settings be a lower
      # precedence than options provided via user on CLI
      def load_deps
        Chef::Knife.new.configure_chef
      end

      # @return [KnifeCloudformation::Provider]
      def provider
        Thread.current[:_provider] ||= KnifeCloudformation::Provider.new(
          :fog => Chef::Config[:knife][:cloudformation][:credentials],
          :async => false
        )
      end

      # @return [FalseClass]
      def use_separate_defaults?
        false
      end

    end

    class << self
      def included(klass)
        klass.instance_eval do

          extend KnifeCloudformation::KnifeBase::ClassMethods
          include KnifeCloudformation::KnifeBase::InstanceMethods
          include KnifeCloudformation::Utils::JSON
          include KnifeCloudformation::Utils::AnimalStrings
          include KnifeCloudformation::Utils::Output

          deps do
            require 'fog'
            Chef::Config[:knife][:cloudformation] ||= Mash.new
            Chef::Config[:knife][:cloudformation][:credentials] ||= Mash.new
            Chef::Config[:knife][:cloudformation][:options] ||= Mash.new
          end

          option(:credentials,
            :short => '-S CREDENTIALS',
            :long => '--credentials CREDENTIALS',
            :description => 'Fog API options. Comma delimited or used multiple times. (-S "aws_access_key_id=MYKEY")',
            :proc => lambda {|val|
              val.split(',').each do |pair|
                key, value = pair.split('=')
                Chef::Config[:knife][:cloudformation][:credentials][key] = value
              end
            }
          )

          # Populate up the hashes so they are available for knife config
          # with issues of nils
          ['knife.cloudformation.credentials', 'knife.cloudformation.options'].each do |stack|
            stack.split('.').inject(Chef::Config) do |memo, item|
              memo[item.to_sym] = Mash.new unless memo[item.to_sym]
              memo[item.to_sym]
            end
          end

        end
      end
    end
  end

end
