require 'knife-cloudformation'

class Chef
  class Knife
    # Cloudformation inspect command
    class CloudformationInspect < Knife

      include KnifeCloudformation::Knife::Base
      include KnifeCloudformation::Utils::Ssher

      banner 'knife cloudformation inspect NAME'

      option(:attribute,
        :short => '-a ATTR',
        :long => '--attribute ATTR',
        :description => 'Dot delimited attribute to view'
      )

      # Run the stack inspection action
      def run
        stack_name = name_args.last
        stack = provider.stacks.get(stack_name)
        if(config[:attribute])
          attr = config[:attribute].split('.').inject(stack) do |memo, key|
            if(memo.public_methods.include?(key.to_sym))
              memo.send(key)
            else
              raise NoMethodError.new "Invalid attribute requested! (#{memo.class}#{key})"
            end
          end
          ui.info "Stack inspect: #{ui.color(stack_name, :green, :bold)}"
          ui.info "  -> #{config[:attribute]}:"
          ui.info MultiJson.dump(
            MultiJson.load(
              MultiJson.dump(attr)
            ),
            :pretty => true
          )
        else
          full_view
        end
      end

    end
  end
end
