require 'knife-cloudformation'

module KnifeCloudformation
  module Utils
    # Output Helpers
    module Output

      # Process things and return items
      #
      # @param things [Array] items to process
      # @param args [Hash] options
      # @option args [TrueClass, FalseClass] :flat flatten result array
      # @option args [Array] :attributes attributes to extract
      # @todo this was extracted from events and needs to be cleaned up
      def process(things, args={})
        @event_ids ||= []
        processed = things.reverse.map do |thing|
          next if @event_ids.include?(thing['id'])
          @event_ids.push(thing['id']).compact!
          if(args[:attributes])
            args[:attributes].map do |key|
              thing[key].to_s
            end
          else
            thing.values
          end
        end
        args[:flat] ? processed.flatten : processed
      end

      # Generate formatted titles
      #
      # @param thing [Object] thing being processed
      # @param args [Hash]
      # @option args [Array] :attributes
      # @return [Array<String>] formatted titles
      def get_titles(thing, args={})
        attrs = args[:attributes] || []
        if(attrs.empty?)
          hash = thing.is_a?(Array) ? thing.first : thing
          hash ||= {}
          attrs = hash.keys
        end
        titles = attrs.map do |key|
          key.gsub(/([a-z])([A-Z])/, '\1 \2')
        end.compact
        if(args[:format])
          titles.map{|s| @ui.color(s, :bold)}
        else
          titles
        end
      end

      # Output stack related things in nice format
      #
      # @param stack [String] name of stack
      # @param things [Array] things to display
      # @param what [String] description of things for output
      # @param args [Symbol] options (:ignore_empty_output)
      def things_output(stack, things, what, *args)
        unless(args.include?(:no_title))
          output = get_titles(things, :format => true, :attributes => allowed_attributes)
        else
          output = []
        end
        columns = allowed_attributes.size
        output += process(things, :flat => true, :attributes => allowed_attributes)
        output.compact!
        if(output.empty?)
          ui.warn 'No information found' unless args.include?(:ignore_empty_output)
        else
          ui.info "#{what.to_s.capitalize} for stack: #{ui.color(stack, :bold)}" if stack
          ui.info "#{ui.list(output, :uneven_columns_across, columns)}"
        end
      end

    end
  end
end
