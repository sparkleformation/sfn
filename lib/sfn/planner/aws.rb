require 'sfn'
require 'sparkle_formation/aws'
require 'hashdiff'

module Sfn
  class Planner
    # AWS specific planner
    class Aws < Planner

      # Customized translator to dereference template
      class Translator < SparkleFormation::Translation

        MAP = {}
        REF_MAPPING = {}
        FN_MAPPING = {}

        # @return [Array<String>] flagged items for value replacement
        attr_reader :flagged

        # Override to init flagged array
        def initialize(template_hash, args={})
          super
          @flagged = []
        end

        # Flag a reference as modified
        #
        # @param ref_name [String]
        # @return [Array<String>]
        def flag_ref(ref_name)
          @flagged << ref_name.to_s
          @flagged.uniq!
        end

        # Check if resource name is flagged
        #
        # @param name [String]
        # @return [TrueClass, FalseClass]
        def flagged?(name)
          @flagged.include?(name.to_s)
        end

        # Apply function if possible
        #
        # @param hash [Hash]
        # @param funcs [Array] allowed functions
        # @return [Hash]
        # @note also allows 'Ref' within funcs to provide mapping
        #   replacements using the REF_MAPPING constant
        def apply_function(hash, funcs=[])
          k,v = hash.first
          if(hash.size == 1 && (k.start_with?('Fn') || k == 'Ref') && (funcs.empty? || funcs.include?(k)))
            case k
            when 'Fn::Join'
              v.last.join(v.first)
            when 'Fn::FindInMap'
              map_holder = mappings[v[0]]
              if(map_holder)
                map_item = map_holder[dereference(v[1])]
                if(map_item)
                  map_item[v[2]]
                else
                  raise "Failed to find mapping item! (#{v[0]} -> #{v[1]})"
                end
              else
                raise "Failed to find mapping! (#{v[0]})"
              end
            when 'Fn::GetAtt'
              func.include?('DEREF') ? dereference(hash) : hash
            when 'Ref'
              if(funcs.include?('DEREF'))
                dereference(hash)
              else
                {'Ref' => self.class.const_get(:REF_MAPPING).fetch(v, v)}
              end
            else
              hash
            end
          else
            hash
          end
        end

        # Override the parent dereference behavior to return junk
        # value on flagged resource match
        #
        # @param hash [Hash]
        # @return [Hash, String]
        def dereference(hash)
          result = nil
          if(hash.is_a?(Hash))
            if(hash.keys.first == 'Ref' && flagged?(hash.values.first))
              result = RUNTIME_MODIFIED
            elsif(hash.keys.first == 'Fn::GetAtt')
              if(hash.values.last.last.start_with?('Outputs.'))
                if(flagged?(hash.values.join('_')))
                  result = RUNTIME_MODIFIED
                end
              elsif(flagged?(hash.values.first))
                result = RUNTIME_MODIFIED
              end
            end
          end
          result.nil? ? super : result
        end

      end

      # Resources that will be replaced on metadata init updates
      REPLACE_ON_CFN_INIT_UPDATE = [
        'AWS::AutoScaling::LaunchConfiguration',
        'AWS::EC2::Instance'
      ]

      # @return [Smash] initialized translators
      attr_accessor :translators

      # Simple overload to load in aws resource set from
      # sparkleformation
      def initialize(*_)
        super
        SfnAws.load!
        @translators = Smash.new
      end

      # Generate update report
      #
      # @param template [Hash] updated template
      # @param parameters [Hash] runtime parameters for update
      #
      # @return [Hash] report
      def generate_plan(template, parameters)
        parameters = Smash[parameters.map{|k,v| [k, v.to_s]}]
        result = Smash.new(
          :stacks => Smash.new(
            origin_stack.name => plan_stack(
              origin_stack,
              template,
              parameters
            )
          ),
          :added => Smash.new,
          :removed => Smash.new,
          :replace => Smash.new,
          :interrupt => Smash.new,
          :unavailable => Smash.new,
          :unknown => Smash.new
        )
        result
      end

      protected

      # Remote custom Stack property from Stack resources within template
      #
      # @param template [Hash]
      # @return [TrueClass]
      def scrub_stack_properties(template)
        if(template['Resources'])
          template['Resources'].each do |name, info|
            if(is_stack?(info['Type']) && info['Properties'].is_a?(Hash))
              info['Properties'].delete('Stack')
            end
          end
        end
        true
      end

      # Set global parameters available for all template translations.
      # These are pseudo-parameters that are provided by the
      # orchestration api runtime.
      #
      # @return [Hash]
      def get_global_parameters(stack)
        Smash.new(
          'AWS::Region' => stack.api.aws_region,
          'AWS::AccountId' => stack.id.split(':')[4],
          'AWS::NotificationARNs' => stack.notification_topics,
          'AWS::StackId' => stack.id,
          'AWS::StackName' => stack.name
        ).merge(config.fetch(:planner, :global_parameters, {}))
      end

      # Generate plan for stack
      #
      # @param stack [Miasma::Models::Orchestration::Stack]
      # @param new_template [Hash]
      # @param new_parameters [Hash]
      # @return [Hash]
      def plan_stack(stack, new_template, new_parameters)
        plan_results = Smash.new(
          :stacks => Smash.new,
          :added => Smash.new,
          :removed => Smash.new,
          :replace => Smash.new,
          :interrupt => Smash.new,
          :unavailable => Smash.new,
          :unknown => Smash.new,
          :outputs => Smash.new,
          :n_outputs => []
        )

        origin_template = dereference_template(
          "#{stack.data.checksum}_origin",
          stack.template,
          Smash[
            stack.parameters.map do |k,v|
              [k, v.to_s]
            end
          ].merge(get_global_parameters(stack))
        )

        translator_key = "#{stack.data.checksum}_#{stack.data.fetch(:logical_id, stack.name)}"
        run_stack_diff(stack, translator_key, plan_results, origin_template, new_template, new_parameters)

        new_checksum = nil
        current_checksum = false
        until(new_checksum == current_checksum)
          current_checksum = plan_results.checksum
          run_stack_diff(stack, translator_key, plan_results, origin_template, new_template, new_parameters)
          new_checksum = plan_results.checksum
        end
        scrub_plan(plan_results)
        plan_results
      end

      # Check if resource type is stack resource type
      #
      # @param type [String]
      # @return [TrueClass, FalseClass]
      def is_stack?(type)
        origin_stack.api.data.fetch(:stack_types, ['AWS::CloudFormation::Stack']).include?(type)
      end

      # Scrub the plan results to only provide highest precedence diff
      # items
      #
      # @param results [Hash]
      # @return [NilClass]
      def scrub_plan(results)
        precedence = [:unavailable, :replace, :interrupt, :unavailable, :unknown]
        until(precedence.empty?)
          key = precedence.shift
          results[key].keys.each do |k|
            precedence.each do |p_key|
              results[p_key].delete(k)
            end
          end
        end
        nil
      end

      # Run the stack diff and populate the result set
      #
      # @param stack [Miasma::Models::Orchestration::Stack] existing stack
      # @param t_key [String] translator key
      # @param plan_result [Smash] plan data to populate
      # @param origin_template [Smash] template of existing stack
      # @param new_template [Smash] template to replace existing
      # @param new_parameters [Smash] parameters to be applied to update
      # @return [NilClass]
      def run_stack_diff(stack, t_key, plan_results, origin_template, new_template, new_parameters)
        translator = translator_for(t_key)
        new_parameters = new_parameters.dup
        if(stack.parameters)
          stack.parameters.each do |k,v|
            if(new_parameters[k].is_a?(Hash))
              val = translator.dereference(new_parameters[k])
              new_parameters[k] = val == new_parameters[k] ? v : val
            end
          end
        end
        new_parameters.merge!(get_global_parameters(stack))
        new_template_hash = new_template.to_smash
        scrub_stack_properties(new_template_hash)

        plan_nested_stacks(stack, translator, origin_template, new_template_hash, plan_results)

        update_template = dereference_template(
          t_key, new_template_hash, new_parameters,
          plan_results[:replace].keys + plan_results[:unavailable].keys
        )

        HashDiff.diff(origin_template, MultiJson.load(MultiJson.dump(update_template))).group_by do |item|
          item[1]
        end.each do |a_path, diff_items|
          register_diff(
            plan_results, a_path, diff_items, translator_for(t_key),
            Smash.new(
              :origin => origin_template,
              :update => update_template
            )
          )
        end
        nil
      end

      # Extract nested stacks and generate plans
      #
      # @param stack [Miasma::Orchestration::Models::Stack]
      # @param translator [Translator]
      # @param origin_template [Smash]
      # @param new_template_hash [Smash]
      # @param plan_results [Smash]
      # @return [NilClass]
      def plan_nested_stacks(stack, translator, origin_template, new_template_hash, plan_results)
        origin_stacks = origin_template.fetch('Resources', {}).find_all do |s_name, s_val|
          is_stack?(s_val['Type'])
        end.map(&:first)
        new_stacks = (new_template_hash['Resources'] || {}).find_all do |s_name, s_val|
          is_stack?(s_val['Type'])
        end.map(&:first)
        [origin_stacks + new_stacks].flatten.compact.uniq.each do |stack_name|
          original_stack = stack.nested_stacks(false).detect do |stk|
            stk.data[:logical_id] == stack_name
          end
          new_stack_exists = is_stack?(new_template_hash.get('Resources', stack_name, 'Type'))
          new_stack_template = new_template_hash.get('Resources', stack_name, 'Properties', 'Stack')
          new_stack_parameters = new_stack_template.fetch('Parameters', Smash.new)
          new_stack_type = new_template_hash.fetch('Resources', stack_name, 'Type',
            origin_template.get('Resources', stack_name, 'Type')
          )
          resource = Smash.new(
            :name => stack_name,
            :type => new_stack_type,
            :properties => []
          )
          if(original_stack && new_stack_template)
            new_stack_parameters = Smash[
              new_stack_parameters.map do |new_param_key, new_param_value|
                [new_param_key, translator.dereference(new_param_value)]
              end
            ]
            result = plan_stack(original_stack, new_stack_template, new_stack_parameters)
            result[:outputs].keys.each do |modified_output|
              translator.flag_ref("#{stack_name}_Outputs.#{modified_output}")
            end
            plan_results[:stacks][stack_name] = result
          elsif(original_stack && (!new_stack_template && !new_stack_exists))
            plan_results[:removed][stack_name] = resource
          elsif(new_stack_template && !original_stack)
            plan_results[:added][stack_name] = resource
          end
        end
        nil
      end

      # Initialize the diff result hash
      #
      # @param diff [Array] Hashdiff result entry
      # @param path [String] modification path within structure
      # @return [Smash]
      def diff_init(diff, path)
        Smash.new.tap do |di|
          if(diff.size > 1)
            updated = diff.detect{|x| x.first == '+'}
            original = diff.detect{|x| x.first == '-'}
            di[:original] = original.last.to_s
            di[:updated] = updated.last.to_s
          else
            diff_data = diff.first
            di[:path] = path
            if(diff_data.size == 3)
              di[diff_data.first == '+' ? :updated : :original] = diff_data.last
            else
              di[:original] = diff_data[diff_data.size - 2].to_s
              di[:updated] = diff_data.last.to_s
            end
          end
        end
      end

      # Register a diff item into the results set
      #
      # @param results [Hash]
      # @param path [String]
      # @param diff [Array]
      # @param templates [Smash]
      # @option :templates [Smash] :origin
      # @option :templates [Smash] :update
      def register_diff(results, path, diff, translator, templates)
        diff_info = diff_init(diff, path)
        if(path.start_with?('Resources'))
          p_path = path.split('.')
          if(p_path.size == 2)
            diff = diff.first
            key = diff.first == '+' ? :added : :removed
            type = (key == :added ? templates[:update] : templates[:origin]).get('Resources', p_path.last, 'Type')
            results[key][p_path.last] = Smash.new(
              :name => p_path.last,
              :type => type,
              :properties => [],
              :diffs => [
                diff_info
              ]
            )
          else
            if(p_path.include?('Properties'))
              resource_name = p_path[1]
              if(p_path.size < 4 && p_path.last == 'Properties')
                property_name = diff.flatten.compact.last.keys.first
              else
                property_name = p_path[3].to_s.sub(/\[\d+\]$/, '')
              end
              type = templates.get(:origin, 'Resources', resource_name, 'Type')
              resource = Smash.new(
                :name => resource_name,
                :type => type,
                :properties => [property_name],
                :diffs => [
                  diff_info.merge(:property_name => property_name)
                ]
              )
              begin
                r_info = SparkleFormation::Resources::Aws.resource_lookup(type)
                r_property = r_info.property(property_name)
                if(r_property)
                  effect = r_property.update_causes(
                    templates.get(:update, 'Resources', resource_name),
                    templates.get(:origin, 'Resources', resource_name)
                  )
                else
                  raise KeyError.new 'Unknown property'
                end
                case effect.to_sym
                when :replacement
                  set_resource(:replace, results, resource_name, resource)
                when :interrupt
                  set_resource(:interrupt, results, resource_name, resource)
                when :unavailable
                  set_resource(:unavailable, results, resource_name, resource)
                when :none
                  # \o/
                else
                  set_resource(:unknown, results, resource_name, resource)
                end
              rescue KeyError
                set_resource(:unknown, results, resource_name, resource)
              end
            elsif(p_path.include?('AWS::CloudFormation::Init'))
              resource_name = p_path[1]
              type = templates[:origin]['Resources'][resource_name]['Type']
              if(REPLACE_ON_CFN_INIT_UPDATE.include?(type))
                set_resource(:replace, results, resource_name,
                  Smash.new(
                    :name => resource_name,
                    :type => type,
                    :properties => ['AWS::CloudFormation::Init'],
                    :diffs => [
                      diff_info
                    ]
                  )
                )
              end
            end
          end
        elsif(path.start_with?('Outputs'))
          o_resource_name = path.split('.')[1]
          if(o_resource_name)
            set_resource(
              :outputs, results, o_resource_name,
              :properties => [],
              :diffs => [
                diff_info
              ]
            )
          end
        end
      end

      # Set resource item into result set
      #
      # @param kind [Symbol]
      # @param results [Hash]
      # @param name [String]
      # @param resource [Hash]
      def set_resource(kind, results, name, resource)
        if(results[kind][name])
          results[kind][name][:properties] += resource[:properties]
          results[kind][name][:properties].uniq!
          results[kind][name][:diffs] += resource[:diffs]
          results[kind][name][:diffs].uniq!
        else
          results[kind][name] = resource
        end
      end

      # Dereference all parameters within template to allow for
      # processing using real values
      #
      # @param t_key [String]
      # @param template [Hash]
      # @param parameters [Hash]
      # @param flagged [Array<String>]
      #
      # @return [Hash]
      def dereference_template(t_key, template, parameters, flagged=[])
        template = template.to_smash
        translator = translator_for(t_key, template, parameters)
        flagged.each do |item|
          translator.flag_ref(item)
        end
        template.keys.each do |t_key|
          next if ['Outputs', 'Resources'].include?(t_key)
          template[t_key] = translator.dereference_processor(
            template[t_key], ['Ref', 'Fn', 'DEREF', 'Fn::FindInMap']
          )
        end
        translator.original.replace(template)
        if(template['Resources'])
          template['Resources'] = translator.dereference_processor(
            template['Resources'], ['Ref', 'Fn', 'DEREF', 'Fn::FindInMap']
          )
        end
        if(template['Outputs'])
          template['Outputs'] = translator.dereference_processor(
            template['Outputs'], ['Ref', 'Fn', 'DEREF', 'Fn::FindInMap']
          )
        end
        translator.original.replace({})
        template
      end

      # Provide a translator instance for given key (new or cached instance)
      #
      # @param t_key [String] identifier
      # @param template [Hash] stack template
      # @param parameters [Hash] stack parameters
      # @return [Translator]
      def translator_for(t_key, template=nil, parameters=nil)
        o_translator = translators[t_key]
        if(template)
          translator = Translator.new(template,
            :parameters => parameters
          )
          if(o_translator)
            o_translator.flagged.each do |i|
              translator.flag_ref(i)
            end
          end
          translators[t_key] = translator
          o_translator = translator
        else
          unless(o_translator)
            o_translator = Translator.new({},
              :parameters => {}
            )
          end
        end
        o_translator
      end

    end
  end
end
