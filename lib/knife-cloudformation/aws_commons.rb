module KnifeCloudformation
  class AwsCommon

    class Stack

      attr_reader :name, :raw_stack, :raw_resources, :common
      
      def initialize(name, common)
        @name = name
        @common = common
        @memo = {
          :events => []
        }
        load_stack
        @force_refresh = false
        @force_refresh = in_progress?
      end

      def load_stack
        @raw_stack = common.aws(:cloud_formation).describe_stacks('StackName' => name).body['Stacks'].first
      end

      def load_resources
        @raw_resources = common.aws(:cloud_formation).list_stack_resources('StackName' => name).body['StackResourceSummaries']
      end

      def refresh?(bool)
        bool || (bool.nil? && @force_refresh)
      end
      
      def status(force_refresh=nil)
        load_stack if refresh?(force_refresh)
        @raw_stack['StackStatus']
      end

      def resources(force_refresh=nil)
        load_resources if @raw_resources.nil? || refresh?(force_refresh)
        @raw_resources
      end

      def destroy
        common.aws(:cloud_formation).destroy_stack(name)
      end

      def events
        options = @memo[:events][name] ? {'NextToken' => @memo[:events][name]} : {}
        res = common.aws(:cloud_formation).describe_stack_events(name, options)
        @memo[:events][name] = res.body['StackToken']
        res.body['StackEvents']
      end

      def in_progress?
        status.to_s.downcase.end_with?('in_progress')
      end

      def complete?
        stat = status.to_s.downcase
        stat.end_with?('complete') || stat.end_with?('failed')
      end

      def failed?
        status.to_s.downcase.end_with?('failed')
      end

      def success?
        status.to_s.downcase.end_with?('complete')
      end

      def outputs(style=:unformatted)
        case style
        when :formatted
          Hash[*(
              @raw_stack.map do |item|
                item.map do |k,v|
                  [k.gsub(/(?<![A-Z])([A-Z])/, '_\1').sub(/^_/, '').downcase.to_sym, v]
                end
              end.flatten
          )]
        when :unformatted
          Hash[*(
              @raw_stack.map do |item|
                item.map do |k,v|
                  [k,v]
                end
              end.flatten
          )]
        else
          @raw_stack['Outputs']
        end
      end

      RESOURCE_FILTER_KEYS = {
        :auto_scaling_group => 'AutoScalingGroupNames'
      }
      
      def expand_resource(resource)
        kind = resource['ResourceType'].split('::')[1]
        kind_snake = common.snake(kind)
        aws = common.aws(kind_snake)
        aws.send("#{common.snake(resource['ResourceType'].split('::').last).to_s.split('_').last}s").get(resource['PhysicalResourceId'])
      end

      def instances
        as_resource = resources.detect{|r|r['ResourceType'] == 'AWS::AutoScaling::AutoScalingGroup'}
        as_group = expand_resource(as_resource)
        as_group.instances.map do |inst|
          common.aws(:ec2).servers.get(inst.id)
        end
      end
      
    end

    FOG_MAP = {
      :ec2 => :compute
    }
    
    def initialize(args={})
      @ui = args[:ui]
      @creds = args[:fog]
      @connections = {}
      @memo = {
        :stacks => {},
        :event_ids => []
      }
    end

    def build_connection(type)
      type = type.to_sym
      type = FOG_MAP[type] if FOG_MAP[type]
      unless(@connections[type])
        puts "TYPE: #{type}"
        if(type == :compute)
          @connections[:compute] = Fog::Compute::AWS.new(@creds)
        else
          Fog.credentials = Fog.symbolize_credentials(@creds)
          @connections[type] = Fog::AWS[type]
          Fog.credentials = {}
        end
      end
      @connections[type]
    end
    alias_method :aws, :build_connection

    def stacks(force_refresh=false)
      @memo.delete(:stack_list) if force_refresh
      unless(@memo[:stack_list])
        @memo[:stack_list] = cf.list_stacks(aws_filter_hash).body['StackSummaries']
      end
      @memo[:stack_list]
    end
    
    def stack(name)
      unless(@memo[:stacks][name])
        @memo[:stacks][name] = Stack.new(name, self)
      end
      @memo[:stacks][name]
    end

    def process(things, args={})
      @event_ids ||= []
      processed = things.reverse.map do |thing|
        next if @memo[:event_ids].include?(thing['EventId'])
        @event_ids.push(thing['EventId']).compact!
        if(args[:attributes])
          args[:attributes].map do |key|
            thing[key].to_s
          end
        else
          thing
        end
      end
      args[:flat] ? processed.flatten : processed
    end

    def get_titles(thing, args={})#format=false)
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

    def camel(string)
      string.to_s.split('_').map{|k| "#{k.slice(0,1).upcase}#{k.slice(1,k.length)}"}.join
    end

    def snake(string)
      string.to_s.gsub(/([a-z])([A-Z])/, '\1_\2').downcase.to_sym
    end
    
  end
end
