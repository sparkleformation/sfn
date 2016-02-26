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
              result = '__MODIFIED_REFERENCE_VALUE__'
            elsif(hash.keys.first == 'Fn::GetAtt')
              if(hash.values.last.last.start_with?('Outputs.'))
                if(flagged?(hash.values.join('_')))
                  result = '__MODIFIED_REFERENCE_VALUE__'
                end
              elsif(flagged?(hash.values.first))
                result = '__MODIFIED_REFERENCE_VALUE__'
              end
            end
          end
          result.nil? ? super : result
        end

      end

      # Resources that will be replaced on metadata init updates
      REPLACE_ON_CFN_INIT_UPDATE = [
        'AWS::AutoScaling::LaunchConfiguration'
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
        Smash.new(
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
      end

      protected

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
          Smash[stack.parameters.map{|k,v| [k, v.to_s]}].merge(get_global_parameters(stack))
        )

        t_key = "#{stack.data.checksum}_#{stack.data.fetch(:logical_id, stack.name)}"
        run_stack_diff(stack, t_key, plan_results, origin_template, new_template, new_parameters)

        new_checksum = nil
        current_checksum = false
        until(new_checksum == current_checksum)
          current_checksum = plan_results.checksum
          run_stack_diff(stack, t_key, plan_results, origin_template, new_template, new_parameters)
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

        o_nested_stacks = origin_template.fetch('Resources', {}).find_all do |s_name, s_val|
          is_stack?(s_val['Type'])
        end.map(&:first)
        n_nested_stacks = new_template_hash.fetch('Resources', {}).find_all do |s_name, s_val|
          is_stack?(s_val['Type'])
        end.map(&:first)
        [o_nested_stacks + n_nested_stacks].flatten.compact.uniq.each do |n_name|
          o_stack = stack.nested_stacks(false).detect{|s| s.data[:logical_id] == n_name}
          n_exists = is_stack?(new_template_hash['Resources'].fetch(n_name, {})['Type'])
          n_template = new_template_hash['Resources'].fetch(n_name, {}).fetch('Properties', {})['Stack']
          n_parameters = new_template_hash['Resources'].fetch(n_name, {}).fetch('Properties', {}).fetch('Parameters', {})
          n_type = new_template_hash['Resources'].fetch(n_name, {})['Type'] ||
            origin_template['Resources'][n_name]['Type']
          resource = Smash.new(
            :name => n_name,
            :type => n_type,
            :properties => []
          )
          if(o_stack && n_template)
            n_parameters.keys.each do |n_key|
              n_parameters[n_key] = translator.dereference(n_parameters[n_key])
            end
            n_results = plan_stack(o_stack, n_template, n_parameters)
            unless(n_results[:outputs].empty?)
              n_results[:outputs].keys.each do |n_output|
                translator.flag_ref("#{n_name}_Outputs.#{n_output}")
              end
            end
            plan_results[:stacks][n_name] = n_results
          elsif(o_stack && (!n_template && !n_exists))
            plan_results[:removed][n_name] = resource
          elsif(n_template && !o_stack)
            plan_results[:added][n_name] = resource
          end
        end

        n_nested_stacks.each do |ns_name|
          new_template_hash['Resources'][ns_name]['Properties'].delete('Stack')
        end

        update_template = dereference_template(
          t_key, new_template_hash, new_parameters,
          plan_results[:replace].keys + plan_results[:unavailable].keys
        )

        HashDiff.diff(origin_template, MultiJson.load(MultiJson.dump(update_template))).group_by do |item|
          item[1]
        end.each do |a_path, diff_items|
          register_diff(
            plan_results, a_path, diff_items, translator_for(t_key),
            :origin => origin_template,
            :update => update_template
          )
        end
        nil
      end

      # Register a diff item into the results set
      #
      # @param results [Hash]
      # @param path [String]
      # @param diff [Array]
      # @param templates [Hash]
      # @option :templates [Hash] :origin
      # @option :templates [Hash] :update
      def register_diff(results, path, diff, translator, templates)
        if(path.start_with?('Resources'))
          p_path = path.split('.')
          if(p_path.size == 2)
            diff = diff.first
            key = diff.first == '+' ? :added : :removed
            type = (key == :added ? templates[:update] : templates[:origin])['Resources'][p_path.last]['Type']
            results[key][p_path.last] = Smash.new(
              :name => p_path.last,
              :type => type,
              :properties => []
            )
          else
            if(p_path.include?('Properties'))
              resource_name = p_path[1]
              property_name = p_path[3].sub(/\[\d+\]$/, '')
              type = templates[:origin]['Resources'][resource_name]['Type']
              info = SfnAws.registry.fetch(type, {})
              effect = info[:full_properties].fetch(property_name, {}).fetch(:update_causes, :unknown).to_sym
              resource = Smash.new(
                :name => resource_name,
                :type => type,
                :properties => [property_name]
              )
              case effect
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
            elsif(p_path.include?('AWS::CloudFormation::Init'))
              resource_name = p_path[1]
              type = templates[:origin]['Resources'][resource_name]['Type']
              if(REPLACE_ON_CFN_INIT_UPDATE.include?(type))
                set_resource(:replace, results, resource_name,
                  Smash.new(
                    :name => resource_name,
                    :type => type,
                    :properties => ['AWS::CloudFormation::Init']
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
              :properties => []
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
