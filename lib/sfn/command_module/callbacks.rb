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
        run_callbacks_for(["before_#{type}", :before, :default], *args)
        result = yield if block_given?
        run_callbacks_for(["after_#{type}", :after, :default], *args)
        result
      end

      # Process requested callbacks
      #
      # @param type [Symbol, String] name of callback type
      # @return [NilClass]
      def run_callbacks_for(type, *args)
        clbks = [type].flatten.compact.map do |c_type|
          res_type = c_type.to_sym == :default ? [type].flatten.compact : [c_type]
          callbacks_for(c_type, res_type)
        end.flatten.compact.uniq.each do |callback_name, callback|
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
      # @param responder [Array<String, Symbol>] matching response methods
      # @return [Array<Method>]
      def callbacks_for(type, responder=[])
        responder = [type].compact.flatten if resopnder.empty?
        [config.fetch(:callbacks, type, [])].flatten.compact.map do |c_name|
          instance = memoize(c_name) do
            begin
              klass = Sfn::Callback.const_get(Bogo::Utility.camel(c_name.to_s))
              klass.new(ui, config, arguments, provider)
            rescue NameError
              raise "Unknown #{type} callback requested: #{c_name} (not found)"
            end
          end
          responder.map do |m_name|
            if(instance.respond_to?(m_name))
              [c_name, instance.method(m_name)]
            end
          end.compact
        end.compact.flatten(1)
      end

    end
  end
end
