require 'sfn'
require 'sparkle_formation/aws'
require 'hashdiff'

module Sfn
  class Planner
    # AWS specific planner
    class Aws < Planner

      # Customized translator to dereference template
      class Translator < SparkleFormation::Translation

        # Override to init flagged array
        def initialize(*_)
          super
          @flagged = []
        end

        # Flag a reference as modified
        #
        # @param ref_name [String]
        # @return [Array<String>]
        def flag_ref(ref_name)
          @flagged << ref_name
          @flagged.uniq!
        end

        # Check if resource name is flagged
        #
        # @param name [String]
        # @return [TrueClass, FalseClass]
        def flagged?(name)
          @flagged.include?(name)
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
          result = super
          if(result.is_a?(Hash) && ['Ref', 'Fn::GetAtt'].include?(result.keys.first) && flagged?(result.values.first))
            '__MODIFIED_REFERENCE_VALUE__'
          else
            result
          end
        end

      end

      # Simple overload to load in aws resource set from
      # sparkleformation
      def initialize(*_)
        super
        SfnAws.load!
      end

      # Generate update report
      #
      # @param template [Hash] updated template
      # @param parameters [Hash] runtime parameters for update
      #
      # @return [Hash] report
      def generate_plan(template, parameters)
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
          :unknown => Smash.new
        )
        o_nested_stacks = stack.nested_stacks(false).map{|s| s.data[:logical_id]}
        n_nested_stacks = new_template['Resources'].find_all do |s_name, s_val|
          s_val['Type'] == 'AWS::CloudFormation::Stack' # TODO use matcher from provider
        end.map(&:first)
        [o_nested_stacks + n_nested_stacks].flatten.compact.uniq.each do |n_name|
          o_stack = stack.nested_stacks(false).detect{|s| s.data[:logcal_id] == n_name}
          n_template = new_template['Resources'].fetch(n_name, {}).fetch('Properties', {}).delete('Stack')
          n_parameters = new_template['Resources'].fetch(n_name, {}).fetch('Properties', {}).delete('Parameters')
          resource = Smash.new(
            :name => n_name,
            :type => 'AWS::CloudFormation::Stack',
            :properties => []
          )
          if(o_stack && n_template)
            plan_results[:stacks][n_name] = plan_stack(o_stack, n_template, n_parameters)
          elsif(o_stack && !n_template)
            plan_results[:removed][n_name] = resource
          elsif(n_template && !o_stack)
            plan_results[:added][n_name] = resource
          else
            raise 'If you see this error message, you are a magician and should conjour some real life unicorns.'
          end
        end
        origin_template = dereference_template(stack.template, stack.parameters)
        update_template = dereference_template(new_template, new_parameters)
        HashDiff.diff(origin_template, update_template).group_by do |item|
          item[1]
        end.each do |a_path, diff_items|
          register_diff(
            plan_results, a_path, diff_items,
            :origin => origin_template,
            :update => update_template
          )
        end
        new_checksum = nil
        current_checksum = false
        until(new_checksum == current_checksum)
          current_checksum = plan_results.checksum
          update_template = dereference_template(new_template, new_parameters, plan_results[:replace].keys + plan_results[:unavailable].keys)
          HashDiff.diff(origin_template, update_template).group_by do |item|
            item[1]
          end.each do |a_path, diff_items|
            register_diff(
              plan_results, a_path, diff_items,
              :origin => origin_template,
              :update => update_template
            )
          end
          new_checksum = plan_results.checksum
        end
        scrub_plan(plan_results)
        plan_results
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

      # Register a diff item into the results set
      #
      # @param results [Hash]
      # @param path [String]
      # @param diff [Array]
      # @param templates [Hash]
      # @option :templates [Hash] :origin
      # @option :templates [Hash] :update
      def register_diff(results, path, diff, templates)
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
              type = templates[:origin]['Resources'][p_path[1]]['Type']
              info = SfnAws.registry[type]
              effect = info[:full_properties].fetch(property_name, {}).fetch(:update_causes, :unknown)
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
            end
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
      # @param template [Hash]
      # @param parameters [Hash]
      #
      # @return [Hash]
      def dereference_template(template, parameters, flagged=[])
        translator = Translator.new(template, :parameters => parameters)
        flagged.each do |item|
          translator.flag_ref(item)
        end
        template['Resources'] = translator.dereference_processor(template['Resources'], ['Ref', 'DEREF'])
        template
      end

    end
  end
end
