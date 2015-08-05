require 'sfn'
require 'sparkle_formation'

module Sfn
  module CommandModule
    # Callback processor helpers
    module Callbacks

      include Bogo::Memoization

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
            args.each do |item|
              callback.call(item)
            end
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
        config.get(:callbacks, type).map do |c_name|
          instance = memoize(c_name) do
            begin
              klass = Sfn::Callback.const_get(Bogo::Utility.camel(type.to_s))
              klass.new(ui)
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
