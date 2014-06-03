require 'knife-cloudformation/cache'
require 'knife-cloudformation/aws_commons'
require 'digest/sha2'

module KnifeCloudformation
  class AwsCommons
    class Stack

      include KnifeCloudformation::Utils::Debug
      include KnifeCloudformation::Utils::JSON
      include KnifeCloudformation::Utils::AnimalStrings

      attr_reader :name, :raw_resources, :common, :cache, :remote_stack

      class << self

        ALLOWED_PARAMETER_ATTRIBUTES = %w(
          Type Default NoEcho AllowedValues AllowedPattern
          MaxLength MinLength MaxValue MinValue Description
          ConstraintDescription
        )

        include KnifeCloudformation::Utils::JSON

        def create(name, definition, aws_common)
          new_stack = aws_common.remote(:orchestration).stacks.new(
            definition.merge(:stack_name => name)
          )
          new_stack.create
        end

        def build_stack_definition(template, options={})
          stack = Mash.new(options)
          enable_capabilities!(stack, template)
          clean_parameters!(template)
          stack[:template] = _to_json(template)
          stack
        end

        # Currently only checking for IAM resources since that's all
        # that is supported for creation
        def enable_capabilities!(stack, template)
          found = Array(template['Resources']).detect do |resource_name, resource|
            resource['Type'].start_with?('AWS::IAM')
          end
          stack[:capabilities] = ['CAPABILITY_IAM'] if found
          nil
        end

        def clean_parameters!(template)
          template.fetch('Parameters', {}).each do |name, options|
            options.delete_if do |attribute, value|
              !ALLOWED_PARAMETER_ATTRIBUTES.include?(attribute)
            end
          end
        end

      end

      def initialize(name, common, raw_stack=nil)
        @name = name
        @common = common
        @cache = cache = Cache.new(common.credentials.merge(:stack => name))
        reset_local
        cache.init(:raw_stack, :stamped)
        if(raw_stack)
          if(common.cache[:stacks])
            if(common.cache[:stacks].stamp > cache[:raw_stack].stamp)
              cache[:raw_stack].value = raw_stack
            end
          else
            cache[:raw_stack].value = raw_stack
          end
        end
        load_stack
        @force_refresh = false
        @force_refresh = in_progress?
      end

      ## Actions ##

      def update(definition)
        if(definition.keys.detect{|k|k.is_a?(Symbol)})
          definition = format_definition(definition)
        end
        res = common.aws(:cloud_formation).update_stack(name, definition)
        reload!
        res
      end

      def format_definition(def_hash)
        new_hash = {}
        def_hash.each do |k,v|
          new_hash[snake(k)] = v
        end
        if(new_hash['template'].is_a?(Hash))
          new_hash['template'] = _to_json(new_hash['template'])
        end
        new_hash
      end

      def destroy
        remote_stack.destroy
        reload!
      end

      def load_stack(*args)
        @remote_stack = common.remote(:orchestration).stacks.find_by_name(name)
        raise LoadError.new("Failed to load stack: #{name}") unless remote_stack
        cache.init(:raw_stack, :stamped)
        cache.init(:raw_stack_lock, :lock)
        cache.locked_action(:raw_stack_lock) do
          if(args.include?(:force) || cache[:raw_stack].update_allowed?)
            cache[:raw_stack].value = Mash.new(remote_stack.attributes)
          end
        end
      end

      def load_resources
        cache.init(:raw_resources, :stamped)
        cache.init(:raw_resources_lock, :lock)
        cache.locked_action(:raw_resources_lock) do
          if(cache[:raw_resources].update_allowed?)
            cache[:raw_resources].value = Mash.new(remote_stack.resources.map(&:attributes))
          end
        end
      end

      def refresh?(bool=nil)
        bool || (bool.nil? && @force_refresh)
      end

      def reset_local
        @local = {
          :nodes => []
        }
      end

      def reload!
        cache.clear! do
          load_stack(:force)
          load_resources
          @force_refresh = in_progress?
        end
        true
      end

      ## Information ##

      def serialize
        _to_json(to_hash)
      end

      def to_hash(extra_data={})
        {
          :template_body => template,
          :parameters => parameters,
          :capabilities => capabilities,
          :disable_rollback => disable_rollback,
          :notification_ARNs => notification_arns,
          :timeout_in_minutes => timeout
        }.merge(extra_data)
      end

      def template
        cache.init(:template, :value)
        unless(cache[:template].value)
          cache[:template].value = _from_json(
            common.aws(:cloud_formation)
              .get_template(name).body['TemplateBody']
          )
        end
        cache[:template].value
      end

      ## Stack metadata ##
      def parameters(raw=false)
        if(raw)
          cache[:raw_stack].value['parameters']
        else
          cache.init(:parameters, :value)
          unless(cache[:parameters].value)
            cache[:parameters].value = Hash[*(
                cache[:raw_stack].value['Parameters'].map do |ary|
                  [ary['ParameterKey'], ary['ParameterValue']]
                end.flatten
            )]
          end
          cache[:parameters].value
        end
      end

      def capabilities
        cache[:raw_stack].value['capabilities']
      end

      def disable_rollback
        cache[:raw_stack].value['disable_rollback']
      end

      def notification_arns
        cache[:raw_stack].value['NotificationARNs']
      end

      def timeout_in_minutes
        cache[:raw_stack].value['timeout_in_minutes']
      end
      alias_method :timeout, :timeout_in_minutes

      def stack_id
        cache[:raw_stack].value['id']
      end
      alias_method :id, :stack_id

      def creation_time
        cache[:raw_stack].value['creation_time']
      end
      alias_method :created_at, :creation_time

      def status(force_refresh=nil)
        return []
        load_stack if refresh?(force_refresh)
        cache[:raw_stack].value['stack_status']
      end

      def resources(force_refresh=nil)
        load_resources if cache[:raw_resources].nil? || refresh?(force_refresh)
        cache[:raw_resources].value
      end

      def events(all=false)
        cache.init(:events, :stamped)
        res = []
        if(cache[:events].value.nil? || refresh?)
          cache.init(:events_lock, :lock)
          cache.locked_action(:events_lock) do
            if(cache[:events].update_allowed?)
              items = remote_stack.events.sort do |b, a|
                Time.parse(a.event_time) <=> Time.parse(b.event_time)
              end
              cache[:events].value = items
            end
          end
        end
        cache[:events].value
      end

      def outputs(style=:unformatted)
        case style
        when :formatted
          Hash[*(
              cache[:raw_stack].value.fetch('Outputs', []).map do |item|
                [item['OutputKey'].gsub(/(?<![A-Z])([A-Z])/, '_\1').sub(/^_/, '').downcase.to_sym, item['OutputValue']]
              end.flatten
          )]
        when :unformatted
          Hash[*(
              cache[:raw_stack].value.fetch('Outputs', []).map do |item|
                [item['OutputKey'], item['OutputValue']]
              end.flatten
          )]
        else
          cache[:raw_stack].value.fetch('Outputs', [])
        end
      end

      def event_start_index(given_events, status)
        Array(given_events).flatten.compact.rindex do |e|
          e['resource_type'] == 'AWS::CloudFormation::Stack' &&
            e['resource_status'] == status.to_s.upcase
        end.to_i
      end

      # min:: do not return value lower than this (defaults to 5)
      # Returns Numeric < 100 to represent completed resources
      # percentage (never returns less than 5)
      def percent_complete(min=5)
        if(complete?)
          100
        else
          all_events = events(:all)
          if(all_events)
            total_expected = template['Resources'].size
            action = performing
            start = event_start_index(all_events, "#{action}_in_progress".to_sym)
            finished = all_events.find_all do |e|
              e['resource_status'] == "#{action}_complete".upcase ||
              e['resource_status'] == "#{action}_failed".upcase
            end.size
            calculated = ((finished / total_expected.to_f) * 100).to_i
            calculated < min ? min : calculated
          else
            100 # Assume deletion and no events == complete
          end
        end
      end

      def raw_stack
        cache[:raw_stack].value
      end

      ## State ##

      def in_progress?
        status.to_s.downcase.end_with?('in_progress')
      end

      def complete?
        stat = status.to_s.downcase
        stat.end_with?('complete') || stat.end_with?('failed')
      end

      def failed?
        stat = status.to_s.downcase
        stat.end_with?('failed') || (stat.include?('rollback') && stat.end_with?('complete'))
      end

      def success?
        !failed? && complete?
      end

      def creating?
        in_progress? && status.to_s.downcase.start_with?('create')
      end

      def deleting?
        in_progress? && status.to_s.downcase.start_with?('delete')
      end

      def updating?
        in_progress? && status.to_s.downcase.start_with?('update')
      end

      def rollbacking?
        in_progress? && status.to_s.downcase.start_with?('rollback')
      end

      def performing
        if(in_progress?)
          status.to_s.downcase.split('_').first.to_sym
        end
      end

      # Lets build in some color coding!
      def red?
        failed? || deleting?
      end

      def yellow?
        !red? && !green?
      end

      def green?
        success? || creating? || updating?
      end

      ## Fog instance helpers ##

      RESOURCE_FILTER_KEYS = {
        :auto_scaling_group => 'AutoScalingGroupNames'
      }

      def expand_resource(resource)
        kind = resource['ResourceType'].split('::')[1]
        kind_snake = snake(kind)
        aws = common.aws(kind_snake)
        aws.send("#{snake(resource['ResourceType'].split('::').last).to_s.split('_').last}s").get(resource['PhysicalResourceId'])
      end

      def nodes
        if(@local[:nodes].empty?)
          as_resources = resources.find_all do |r|
            r['ResourceType'] == 'AWS::AutoScaling::AutoScalingGroup'
          end
          value = as_resources.map do |as_resource|
            as_group = expand_resource(as_resource)
            as_group.instances.map do |inst|
              common.aws(:ec2).servers.get(inst.id)
            end
          end.flatten
          @local[:nodes] = value unless in_progress? || value.empty?
        end
        value || @local[:nodes]
      end

      def nodes_data(*args)
        cache_key = ['nd', name, Digest::SHA256.hexdigest(args.map(&:to_s).join)].join('_')
        cache.init(cache_key, :value)
        unless(cache[cache_key].value)
          data = nodes.map do |n|
            [:id, args].flatten.compact.map do |k|
              n.send(k)
            end
          end
        end
        unless(data && !data.empty?)
          cache[cache_key].value = data unless in_progress?
        end
        data || cache[cache_key].value || []
      end

    end
  end
end
