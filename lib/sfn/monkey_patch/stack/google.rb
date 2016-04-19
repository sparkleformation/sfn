require 'sfn'

module Sfn
  module MonkeyPatch
    module Stack
      module Google

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
          deref.call(Smash.new(:resources => copy_template.get(:config, :content, :resources)))
        end

      end
    end
  end
end
