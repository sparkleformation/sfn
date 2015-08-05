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
        type = self.class.name.split('::').last
        run_callbacks_for(:before, *args)
        run_callbacks_for("before_#{type}", *args)
        result = yield if block_given?
        run_callbacks_for("after_#{type}", *args)
        run_callbacks_for(:after, *args)
        result
      end

      # Process requested callbacks
      #
      # @param type [Symbol, String] name of callback type
      # @return [NilClass]
      def run_callbacks_for(type, *args)
        callbacks_for(type).each do |callback_name, callback|
          ui.info "Callback #{ui.color(type.to_s, :bold)} #{callback_name}: #{ui.color('starting', :yellow)}"
          if(args.empty?)
            callback.call
          else
            callback.call(*args)
          end
          ui.info "Callback #{ui.color(type.to_s, :bold)} #{callback_name}: #{ui.color('complete', :green)}"
        end
        nil
      end

      # Fetch valid callbacks for given type
      #
      # @param type [Symbol, String] name of callback type
      # @return [Array<Method>]
      def callbacks_for(type)
        config.fetch(:callbacks, type, []).map do |c_name|
          instance = memoize(c_name) do
            begin
              klass = Sfn::Callback.const_get(Bogo::Utility.camel(type.to_s))
              klass.new(ui, config, arguments, provider)
            rescue NameError
              raise "Unknown #{type} callback requested: #{c_name} (not found)"
            end
          end
          if(instance.respond_to?(type))
            instance.method(type)
          end
        end.compact
      end

    end
  end
end
