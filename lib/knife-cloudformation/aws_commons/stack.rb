require 'knife-cloudformation/aws_commons.rb'

module KnifeCloudformation
  class AwsCommons
    class Stack

      include KnifeCloudformation::Utils::JSON

      attr_reader :name, :raw_stack, :raw_resources, :common

      class << self

        include KnifeCloudformation::Utils::JSON

        def create(name, definition, aws_common)
          aws_common.aws(:cloud_formation).create_stack(name, definition)
          new(name, aws_common)
        end

        def build_stack_definition(template, options={})
          stack = Mash.new
          options.each do |key, value|
            format_key = key.split('_').map do |k|
              "#{k.slice(0,1).upcase}#{k.slice(1,k.length)}"
            end.join
            stack[format_key] = value
          end
          enable_capabilities!(stack, template)
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

      end

      def initialize(name, common)
        @name = name
        @common = common
        @memo = {}
        load_stack
        @force_refresh = false
        @force_refresh = in_progress?
      end

      ## Actions ##

      def update(definition)
        res = common.aws(:cloud_formation).update_stack(name, definition)
        reload!
        res
      end

      def destroy
        res = common.aws(:cloud_formation).delete_stack(name)
        reload!
        res
      end

      def load_stack
        @raw_stack = common.aws(:cloud_formation).describe_stacks('StackName' => name).body['Stacks'].first
      end

      def load_resources
        @raw_resources = common.aws(:cloud_formation).describe_stack_resources('StackName' => name).body['StackResources']
      end

      def refresh?(bool)
        bool || (bool.nil? && @force_refresh)
      end

      def reload!
        load_stack
        load_resources
        @force_refresh = in_progress?
        @memo = {}
        true
      end

      ## Information ##

      def serialize
        _to_json(to_hash)
      end

      def to_hash(extra_data={})
        {
          :template => template,
          :parameters => parameters,
          :capabilities => capabilities,
          :disable_rollback => disable_rollback,
          :notification_ARNs => notification_arns,
          :timeout_in_minutes => timeout
        }.merge(extra_data)
      end

      def template
        unless(@memo[:template])
          @memo[:template] = _from_json(
            common.aws(:cloud_formation)
              .get_template(name).body['TemplateBody']
          )
        end
        @memo[:template]
      end

      def parameters
        unless(@memo[:parameters])
          @memo[:parameters] = Hash[*(
              @raw_stack['Parameters'].map do |ary|
                [ary['ParameterKey'], ary['ParameterValue']]
              end.flatten
          )]
        end
        @memo[:parameters]
      end

      def capabilities
        @raw_stack['Capabilities']
      end

      def disable_rollback
        @raw_stack['DisableRollback']
      end

      def notification_arns
        @raw_stack['NotificationARNs']
      end

      def status(force_refresh=nil)
        load_stack if refresh?(force_refresh)
        @raw_stack['StackStatus']
      end

      def resources(force_refresh=nil)
        load_resources if @raw_resources.nil? || refresh?(force_refresh)
        @raw_resources
      end

      def events(all=false)
        res = common.aws(:cloud_formation).describe_stack_events(name).body['StackEvents']
        @memo[:events] ||= []
        res.delete_if{|e| @memo[:events].include?(e['EventId'])}
        @memo[:events] += res.map{|e| e['EventId']}
        @memo[:events].uniq!
        res
      end

      def outputs(style=:unformatted)
        case style
        when :formatted
          Hash[*(
              @raw_stack['Outputs'].map do |item|
                [item['OutputKey'].gsub(/(?<![A-Z])([A-Z])/, '_\1').sub(/^_/, '').downcase.to_sym, item['OutputValue']]
              end.flatten
          )]
        when :unformatted
          Hash[*(
              @raw_stack['Outputs'].map do |item|
                [item['OutputKey'], item['OutputValue']]
              end.flatten
          )]
        else
          @raw_stack['Outputs']
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
        !failed?
      end

      ## Fog instance helpers ##

      RESOURCE_FILTER_KEYS = {
        :auto_scaling_group => 'AutoScalingGroupNames'
      }

      def expand_resource(resource)
        kind = resource['ResourceType'].split('::')[1]
        kind_snake = common.snake(kind)
        aws = common.aws(kind_snake)
        aws.send("#{common.snake(resource['ResourceType'].split('::').last).to_s.split('_').last}s").get(resource['PhysicalResourceId'])
      end

      def nodes
        as_resources = resources.find_all{|r|r['ResourceType'] == 'AWS::AutoScaling::AutoScalingGroup'}
        as_resources.map do |as_resource|
          as_group = expand_resource(as_resource)
          as_group.instances.map do |inst|
            common.aws(:ec2).servers.get(inst.id)
          end
        end.flatten
      end

    end
  end
end
