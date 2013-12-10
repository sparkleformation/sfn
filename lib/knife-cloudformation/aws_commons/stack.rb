require 'knife-cloudformation/cache'
require 'knife-cloudformation/aws_commons'
require 'digest/sha2'

module KnifeCloudformation
  class AwsCommons
    class Stack

      include KnifeCloudformation::Utils::Debug
      include KnifeCloudformation::Utils::JSON
      include KnifeCloudformation::Utils::AnimalStrings

      attr_reader :name, :raw_stack, :raw_resources, :common

      class << self

        ALLOWED_PARAMETER_ATTRIBUTES = %w(
          Type Default NoEcho AllowedValues AllowedPattern
          MaxLength MinLength MaxValue MinValue Description
          ConstraintDescription
        )

        include KnifeCloudformation::Utils::JSON

        def create(name, definition, aws_common)
          aws_common.aws(:cloud_formation).create_stack(name, definition)
          new(name, aws_common)
        end

        def build_stack_definition(template, options={})
          stack = Mash.new
          options.each do |key, value|
            format_key = key.to_s.split('_').map do |k|
              "#{k.slice(0,1).upcase}#{k.slice(1,k.length)}"
            end.join
            stack[format_key] = value
          end
          enable_capabilities!(stack, template)
          clean_parameters!(template)
          stack['TemplateBody'] = _to_json(template)
          stack
        end

        # Currently only checking for IAM resources since that's all
        # that is supported for creation
        def enable_capabilities!(stack, template)
          found = Array(template['Resources']).detect do |resource_name, resource|
            resource['Type'].start_with?('AWS::IAM')
          end
          stack['Capabilities'] = ['CAPABILITY_IAM'] if found
          nil
        end

        def clean_parameters!(template)
          template['Parameters'].each do |name, options|
            options.delete_if do |attribute, value|
              !ALLOWED_PARAMETER_ATTRIBUTES.include?(attribute)
            end
          end
        end

      end

      def initialize(name, common, raw_stack=nil)
        @name = name
        @common = common
        @memo = Cache.new(common.credentials.merge(:stack => name))
        reset_local
        @memo.init(:raw_stack, :stamped)
        if(raw_stack)
          if(@memo[:stacks])
            if(@memo[:stacks].stamp > @memo[:raw_stack].stamp)
              @memo[:raw_stack].value = raw_stack
            end
          else
            @memo[:raw_stack].value = raw_stack
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
          new_hash[camel(k)] = v
        end
        if(new_hash['TemplateBody'].is_a?(Hash))
          new_hash['TemplateBody'] = _to_json(new_hash['TemplateBody'])
        end
        new_hash
      end

      def destroy
        res = common.aws(:cloud_formation).delete_stack(name)
        reload!
        res
      end

      def load_stack(*args)
        @memo.init(:raw_stack, :stamped)
        begin
          @memo.init(:raw_stack_lock, :lock)
          @memo[:raw_stack_lock].lock do
            if(args.include?(:force) || @memo[:raw_stack].update_allowed?)
              @memo[:raw_stack].value = common.aws(:cloud_formation)
                .describe_stacks('StackName' => name)
                .body['Stacks'].first
            end
          end
        rescue => e
          if(defined?(Redis) && e.is_a?(Redis::Lock::LockTimeout))
            # someone else is updating
            debug 'Got lock timeout on stack load'
          else
            raise
          end
        end
      end

      def load_resources
        @memo.init(:raw_resources, :stamped)
        begin
          @memo.init(:raw_resources_lock, :lock)
          @memo[:raw_resources_lock].lock do
            if(@memo[:raw_resources].update_allowed?)
              @memo[:raw_resources].value = common.aws(:cloud_formation)
                .describe_stack_resources('StackName' => name)
                .body['StackResources']
            end
          end
        rescue => e
          if(defined?(Redis) && e.is_a?(Redis::Lock::LockTimeout))
            debug 'Got lock timeout on resource load'
          else
            raise e
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
        @memo.clear! do
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
        @memo.init(:template, :value)
        unless(@memo[:template].value)
          @memo[:template].value = _from_json(
            common.aws(:cloud_formation)
              .get_template(name).body['TemplateBody']
          )
        end
        @memo[:template].value
      end

      ## Stack metadata ##
      def parameters(raw=false)
        if(raw)
          @memo[:raw_stack].value['Parameters']
        else
          @memo.init(:parameters, :value)
          unless(@memo[:parameters].value)
            @memo[:parameters].value = Hash[*(
                @memo[:raw_stack].value['Parameters'].map do |ary|
                  [ary['ParameterKey'], ary['ParameterValue']]
                end.flatten
            )]
          end
          @memo[:parameters].value
        end
      end

      def capabilities
        @memo[:raw_stack].value['Capabilities']
      end

      def disable_rollback
        @memo[:raw_stack].value['DisableRollback']
      end

      def notification_arns
        @memo[:raw_stack].value['NotificationARNs']
      end

      def timeout_in_minutes
        @memo[:raw_stack].value['TimeoutInMinutes']
      end
      alias_method :timeout, :timeout_in_minutes

      def stack_id
        @memo[:raw_stack].value['StackId']
      end
      alias_method :id, :stack_id

      def creation_time
        @memo[:raw_stack].value['CreationTime']
      end
      alias_method :created_at, :creation_time

      def status(force_refresh=nil)
        load_stack if refresh?(force_refresh)
        @memo[:raw_stack].value['StackStatus']
      end

      def resources(force_refresh=nil)
        load_resources if @memo[:raw_resources].nil? || refresh?(force_refresh)
        @memo[:raw_resources].value
      end

      def events(all=false)
        @memo.init(:events, :stamped)
        res = []
        if(@memo[:events].value.nil? || refresh?)
          begin
            @memo.init(:events_lock, :lock)
            @memo[:events_lock].lock do
              if(@memo[:events].update_allowed?)
                res = common.aws(:cloud_formation).describe_stack_events(name).body['StackEvents']
                current = @memo[:events].value || []
                current_events = current.map{|e| e['EventId']}
                res.delete_if{|e| current_events.include?(e['EventId'])}
                current += res
                current.uniq!
                current.sort!{|x,y| x['Timestamp'] <=> y['Timestamp']}
                @memo[:events].value = current
              end
            end
          rescue => e
            if(defined?(Redis) && e.is_a?(Redis::Lock::LockTimeout))
              debug 'Got lock timeout on events'
            else
              raise
            end
          end
        end
        all ? @memo[:events].value : res
      end

      def outputs(style=:unformatted)
        case style
        when :formatted
          Hash[*(
              @memo[:raw_stack].value['Outputs'].map do |item|
                [item['OutputKey'].gsub(/(?<![A-Z])([A-Z])/, '_\1').sub(/^_/, '').downcase.to_sym, item['OutputValue']]
              end.flatten
          )]
        when :unformatted
          Hash[*(
              @memo[:raw_stack].value['Outputs'].map do |item|
                [item['OutputKey'], item['OutputValue']]
              end.flatten
          )]
        else
          @memo[:raw_stack].value['Outputs']
        end
      end

      def event_start_index(given_events, status)
        Array(given_events).flatten.compact.rindex do |e|
          e['ResourceType'] == 'AWS::CloudFormation::Stack' &&
            e['ResourceStatus'] == status.to_s.upcase
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
          total_expected = template['Resources'].size
          action = performing
          start = event_start_index(all_events, "#{action}_in_progress".to_sym)
          finished = all_events.find_all do |e|
            e['ResourceStatus'] == "#{action}_complete".upcase ||
            e['ResourceStatus'] == "#{action}_failed".upcase
          end.size
          calculated = ((finished / total_expected.to_f) * 100).to_i
          calculated < min ? min : calculated
        end
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
          @local[:nodes] = value unless in_progress?
        end
        value || @local[:nodes]
      end

      def nodes_data(*args)
        cache_key = ['nd', name, Digest::SHA256.hexdigest(args.map(&:to_s).join)].join('_')
        @memo.init(cache_key, :value)
        unless(@memo[cache_key].value)
          data = nodes.map do |n|
            [:id, args].flatten.compact.map do |k|
              n.send(k)
            end
          end
        end
        unless(data.empty?)
          @memo[cache_key].value = data unless in_progress?
        end
        data || @memo[cache_key].value
      end

    end
  end
end
