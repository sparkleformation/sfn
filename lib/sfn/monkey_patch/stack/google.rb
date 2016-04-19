require 'sfn'

module Sfn
  module MonkeyPatch
    module Stack
      # Google specific monkey patch implementations
      module Google

        # Helper module to allow nested stack behavior to function as expected
        # internally within sfn
        module PretendStack

          # disable reload
          def reload
            self
          end

          # disable template load
          def perform_template_load
            Smash.new
          end

          # only show resources associated to this stack
          def resources
            collection = Miasma::Models::Orchestration::Stack::Resources.new(self)
            collection.define_singleton_method(:perform_population) do
              valid = stack.sparkleish_template.fetch(:resources, {}).keys
              stack.custom[:resources].find_all{|r| valid.include?(r[:name])}.map do |attrs|
                Miasma::Models::Orchestration::Stack::Resource.new(stack, attrs).valid_state
              end
            end
            collection
          end

          # Sub-stacks never provide events
          def events
            collection = Miasma::Models::Orchestration::Stack::Events.new(self)
            collection.define_singleton_method(:perform_population){ [] }
            collection
          end
        end

        # Return all stacks contained within this stack
        #
        # @param recurse [TrueClass, FalseClass] recurse to fetch _all_ stacks
        # @return [Array<Miasma::Models::Orchestration::Stack>]
        def nested_stacks_google(recurse=true)
          my_template = sparkleish_template
          n_stacks = sparkleish_template[:resources].map do |s_name, content|
            if(content[:type] == 'sparkleformation.stack')
              n_stack = self.class.new(api)
              n_stack.extend PretendStack
              n_layout = custom.fetch(:layout, {}).fetch(:resources, []).detect{|r| r[:name] == name}
              n_layout = (n_layout || custom.fetch(:layout, {})).fetch(:resources, []).detect{|r| r[:name] == s_name} || Smash.new
              n_stack.load_data(
                :name => s_name,
                :id => s_name,
                :template => content.get(:properties, :stack),
                :outputs => n_layout.fetch('outputs', []).map{|o_val| Smash.new(:key => o_val[:name], :value => o_val['finalValue'])},
                :custom => {
                  :resources => resources.all.map(&:attributes),
                  :layout => n_layout
                }
              ).valid_state
              n_stack.data[:logical_id] = s_name
              n_stack.data[:parent_stack] = self
              n_stack
            end
          end.compact
          if(recurse)
            (n_stacks + n_stacks.map(&:nested_stacks)).flatten.compact
          else
            n_stacks
          end
        end

        # @return [Hash] restructured google template
        def sparkleish_template_google
          copy_template = template.to_smash
          deref = lambda do |template|
            result = template.to_smash
            (result.delete(:resources) || []).each do |t_resource|
              t_name = t_resource.delete(:name)
              if(t_resource[:type].to_s.end_with?('.jinja'))
                schema = copy_template.fetch(:config, :content, :imports, []).delete("#{t_resource[:type]}.schema")
                schema_content = copy_template.fetch(:imports, []).detect do |s_item|
                  s_item[:name] == schema
                end
                if(schema_content)
                  t_resource.set(:parameters, schema_content.get(:content, :properties))
                end
                n_template = copy_template.fetch(:imports, []).detect do |s_item|
                  s_item[:name] == t_resource[:type]
                end
                if(n_template)
                  t_resource[:type] = 'sparkleformation.stack'
                  current_properties = t_resource.delete(:properties)
                  t_resource.set(:properties, :parameters, current_properties) if current_properties
                  t_resource.set(:properties, :stack, deref.call(n_template[:content]))
                end
              end
              result.set(:resources, t_name, t_resource)
            end
            result
          end
          s_template = deref.call(Smash.new(:resources => copy_template.get(:config, :content, :resources)))
          if(s_template.empty?)
            template.to_smash
          else
            layout = custom[:layout].to_smash
            layout.delete(:resources).each do |l_resource|
              layout.set(:resources, l_resource.delete(:name), l_resource)
            end
            s_template.fetch(:resources, name, :properties, :stack, s_template)
          end
        end

      end
    end
  end
end
