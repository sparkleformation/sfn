require 'sfn'
require 'sparkle_formation'

module Sfn
  module CommandModule
    # Callback processor helpers
    module Callbacks
      include Bogo::Memoization

      # Run expected callbacks around action
      #
      # @yieldblock api action to run
      # @yieldresult [Object] result from call
      # @return [Object] result of yield block
      def api_action!(*args)
        type = self.class.name.split('::').last.downcase
        run_callbacks_for(["before_#{type}", :before], *args)
        result = nil
        begin
          result = yield if block_given?
          run_callbacks_for(["after_#{type}", :after], *args)
          result
        rescue => err
          run_callbacks_for(["failed_#{type}", :failed], *(args + [err]))
          raise
        end
      end

      # Process requested callbacks
      #
      # @param type [Symbol, String] name of callback type
      # @return [NilClass]
      def run_callbacks_for(type, *args)
        types = [type].flatten.compact
        type = types.first
        clbks = types.map do |c_type|
          callbacks_for(c_type)
        end.flatten(1).compact.uniq.each do |item|
          callback_name, callback, quiet = item
          quiet = true if config[:print_only]
          ui.info "Callback #{ui.color(type.to_s, :bold)} #{callback_name}: #{ui.color('starting', :yellow)}" unless quiet
          if args.empty?
            callback.call
          else
            callback.call(*args)
          end
          ui.info "Callback #{ui.color(type.to_s, :bold)} #{callback_name}: #{ui.color('complete', :green)}" unless quiet
        end
        nil
      end

      # Fetch valid callbacks for given type
      #
      # @param type [Symbol, String] name of callback type
      # @param responder [Array<String, Symbol>] matching response methods
      # @return [Array<Method>]
      def callbacks_for(type)
        ([config.fetch(:callbacks, type, [])].flatten.compact + [config.fetch(:callbacks, :default, [])].flatten.compact).map do |c_name|
          instance = memoize(c_name) do
            begin
              klass = Sfn::Callback.const_get(Bogo::Utility.camel(c_name.to_s))
              klass.new(ui, config, arguments, provider)
            rescue NameError => e
              ui.debug "Callback type lookup error: #{e.class} - #{e}"
              raise NameError.new("Unknown #{type} callback requested: #{c_name} (not found)")
            end
          end
          if instance.respond_to?(type)
            [c_name, instance.method(type), instance.respond_to?(:quiet) ? instance.quiet : false]
          end
        end.compact
      end
    end
  end
end
