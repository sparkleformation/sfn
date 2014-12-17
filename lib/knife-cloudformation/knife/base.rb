require 'chef/knife'
require 'knife-cloudformation'

module KnifeCloudformation
  module Knife
    # Base to build cloudformation related knife commands
    module Base

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
            ui.fatal "Exception information: #{e.class}: #{e.message}\n#{e.backtrace.join("\n")}\n"
            if(e.is_a?(Miasma::Error::ApiError))
              ui.fatal "Response body: #{e.response.body.to_s.inspect}"
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

        # Wrapper to allow consistent exception handling
        def run
          begin
            _run
          rescue => e
            ui.fatal "Unexpected Error: #{e.message}"
            _debug(e)
            exit 1
          end
        end

      end

      module ClassMethods

        # @return [KnifeCloudformation::Provider]
        def provider
          Thread.current[:_provider] ||= KnifeCloudformation::Provider.new(
            :miasma => Chef::Config[:knife][:cloudformation][:credentials],
            :async => false,
            :fetch => false
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

            extend KnifeCloudformation::Knife::Base::ClassMethods
            include KnifeCloudformation::Knife::Base::InstanceMethods
            include KnifeCloudformation::Utils::JSON
            include KnifeCloudformation::Utils::AnimalStrings
            include KnifeCloudformation::Utils::Output

            deps do
              Chef::Knife.new.configure_chef
              require 'miasma'
              Chef::Config[:knife][:cloudformation] ||= Mash.new
              Chef::Config[:knife][:cloudformation][:credentials] ||= Mash.new
              Chef::Config[:knife][:cloudformation][:options] ||= Mash.new
              Chef::Config[:knife][:cloudformation][:ignore_parameters] = []
              %w(poll interactive_parameters apply_nesting).each do |key|
                if(Chef::Config[:knife][:cloudformation][key].nil?)
                  Chef::Config[:knife][:cloudformation][key] = true
                end
              end
            end

            option(:credentials,
              :short => '-S CREDENTIALS',
              :long => '--credentials CREDENTIALS',
              :description => 'Miasma API options. Comma delimited or used multiple times. (-S "aws_access_key_id=MYKEY")',
              :proc => lambda {|val|
                val.split(',').each do |pair|
                  key, value = pair.split('=')
                  Chef::Config[:knife][:cloudformation][:credentials][key] = value
                end
              }
            )

            option(:ignore_parameter,
              :long => '--ignore-parameter PARAMETER_NAME',
              :description => 'Parameter to ignore during modifications (can be used multiple times)',
              :proc => lambda{|val| Chef::Config[:knife][:cloudformation][:ignore_parameters].push(val).uniq! }
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
end
