require 'fog'
require 'knife-cloudformation/utils'
require 'knife-cloudformation/cache'

Dir.glob(File.join(File.dirname(__FILE__), 'aws_commons/*.rb')).each do |item|
  require "knife-cloudformation/aws_commons/#{File.basename(item).sub('.rb', '')}"
end

module KnifeCloudformation
  class AwsCommons

    FOG_MAP = {
      :ec2 => :compute
    }

    attr_reader :credentials

    def initialize(args={})
      @ui = args[:ui]
      @credentials = @creds = args[:fog]
      @connections = {}
      @memo = Cache.new(credentials)
    end

    def clear_cache(*types)
      @memo.clear!(*types)
      true
    end

    def build_connection(type)
      type = type.to_sym
      type = FOG_MAP[type] if FOG_MAP[type]
      unless(@connections[type])
        case type
        when :compute
          @connections[:compute] = Fog::Compute::AWS.new(@creds)
        when :dns
          dns_creds = @creds.dup
          dns_creds.delete(:region) || dns_creds.delete('region')
          @connections[:dns] = Fog::DNS::AWS.new(dns_creds)
        else
          Fog.credentials = Fog.symbolize_credentials(@creds)
          @connections[type] = Fog::AWS[type]
          Fog.credentials = {}
        end
      end
      @connections[type]
    end
    alias_method :aws, :build_connection

    DEFAULT_STACK_STATUS = %w(
      CREATE_IN_PROGRESS CREATE_COMPLETE CREATE_FAILED
      ROLLBACK_IN_PROGRESS ROLLBACK_COMPLETE ROLLBACK_FAILED
      UPDATE_IN_PROGRESS UPDATE_COMPLETE UPDATE_COMPLETE_CLEANUP_IN_PROGRESS
      UPDATE_ROLLBACK_IN_PROGRESS UPDATE_ROLLBACK_FAILED
      UPDATE_ROLLBACK_COMPLETE_CLEANUP_IN_PROGRESS UPDATE_ROLLBACK_COMPLETE
      DELETE_IN_PROGRESS DELETE_FAILED
    )

    def stacks(args={})
      status = args[:status] || DEFAULT_STACK_STATUS
      cache_key = ['stack_list', status.hash.to_s].join('_')
      cache_key_lock = [cache_key, 'lock'].join('_')
      @memo.init(cache_key, :value)
      @memo[cache_key].value = nil if args[:force_refresh]
      unless(@memo[:stack_list][key])
        begin
          @memo.init(cache_key_lock, :lock)
          @memo[cache_key_lock] do
            count = 0
            if(status.map(&:downcase).include?('none'))
              filter = {}
            else
              filter = Hash[*(
                  status.map do |n|
                    count += 1
                    ["StackStatusFilter.member.#{count}", n]
                  end.flatten
              )]
            end
            @memo[cache_key].value = aws(:cloud_formation).list_stacks(filter).body['StackSummaries']
          end
        rescue Redis::Lock::LockTimeout
          debug 'Got lock timeout on stacks list'
        end
      end
      @memo[cache_key].value
    end

    def name_from_stack_id(name)
      found = stacks.detect do |s|
        s['StackId'] == name
      end
      if(found)
        s['StackName']
      else
        raise "Failed to locate stack with ID: #{name}"
      end
    end

    def stack(*names)
      names = names.map do |name|
        if(name.start_with?('arn:'))
          name_from_stack_id(name)
        else
          name
        end
      end
      @memo.init(:stacks, :hash)
      if(names.size == 1)
        name = names.first
        unless(@memo[:stacks][name])
          @memo[:stacks][name] = Stack.new(name, self)
        end
        @memo[:stacks][name]
      else
        to_fetch = names - @memo[:stacks].keys
        slim_stacks = {}
        unless(to_fetch.empty?)
          to_fetch.each do |name|
            slim_stacks[name] = Stack.new(name, self, stacks.detect{|s| s['StackName'] == name})
          end
        end
        result = names.map do |n|
          @memo[:stacks][n] || slim_stacks[n]
        end
        result
      end
    end

    def create_stack(name, definition)
      Stack.create(name, definition, self)
    end

    # Output Helpers

    def process(things, args={})
      @event_ids ||= []
      processed = things.reverse.map do |thing|
        next if @event_ids.include?(thing['EventId'])
        @event_ids.push(thing['EventId']).compact!
        if(args[:attributes])
          args[:attributes].map do |key|
            thing[key].to_s
          end
        else
          thing.values
        end
      end
      args[:flat] ? processed.flatten : processed
    end

    def get_titles(thing, args={})
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
  end
end
