require 'fog'
require 'knife-cloudformation/utils'
require 'knife-cloudformation/cache'

Dir.glob(File.join(File.dirname(__FILE__), 'aws_commons/*.rb')).each do |item|
  require "knife-cloudformation/aws_commons/#{File.basename(item).sub('.rb', '')}"
end

module KnifeCloudformation
  class AwsCommons

    class << self
      def logger=(l)
        @logger = l
      end

      def logger
        unless(@logger)
          require 'logger'
          @logger = Logger.new($stdout)
          @logger.level = ENV['DEBUG'] ? Logger::DEBUG : Logger::INFO
        end
        @logger
      end
    end

    include KnifeCloudformation::Utils::AnimalStrings
    include KnifeCloudformation::Utils::Debug

    FOG_MAP = {
      :ec2 => :compute
    }

    attr_reader :credentials, :local
    attr_accessor :disconnect_long_jobs

    def initialize(args={})
      @ui = args[:ui]
      @credentials = @creds = args[:fog]
      @disconnect_long_jobs = args[:disconnect_long_jobs]
      @throttled = []
      @connections = {}
      @memo = Cache.new(credentials)
      @memo.init(:stacks_lock, :lock)
      @memo.init(:stacks, :stamped)
      @memo.init(:lookup_map, :value)
      @memo[:lookup_map].value = {} unless @memo[:lookup_map].value
      @local = {
        :stacks => {},
        :lookup_map => {},
        :lookup_set => 0,
        :lookup_reset => 3
      }
      lookup_map
    end

    def logger
      @logger || self.class.logger
    end

    def logger=(l)
      @logger = l
    end

    def cache
      @memo
    end

    def lookup_map
      if(Time.now.to_f - local[:lookup_set] > local[:lookup_reset])
        local[:lookup_set] = Time.now.to_f
        local[:lookup_map] = cache[:lookup_map].value
      end
      local[:lookup_map]
    end

    def lookup_map_set(hash)
      local[:lookup_map] = hash
      local[:lookup_set] = Time.now.to_f
      cache[:lookup_map].value = hash
      long_running_job(:lookup_set_stack_cacher) do
        stack(*hash.keys)
      end
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
        when :dns, :storage # No regions allowed!
          filtered_creds = @creds.dup
          filtered_creds.delete(:region) || filtered_creds.delete('region')
          @connections[type] = (type == :dns ? Fog::DNS::AWS : Fog::Storage::AWS).new(filtered_creds)
        else
          begin
            Fog.credentials = Fog.symbolize_credentials(@creds)
            @connections[type] = Fog::AWS[type]
            Fog.credentials = {}
          rescue NameError
            klass = [camel(type.to_s), 'AWS'].inject(Fog) do |memo, item|
              memo.const_defined?(item) ? memo.const_get(item) : break
            end
            if(klass)
              @connections[type] = klass.new(Fog.symbolize_credentials(@creds))
            else
              raise
            end
          end
        end
      end
      if(block_given?)
        throttleable do
          yield @connections[type]
        end
      else
        @connections[type]
      end
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
      status = Array(args[:status] || DEFAULT_STACK_STATUS).flatten.compact.map do |stat|
        stat.to_s.upcase
      end
      if(args[:cache_time])
        @memo[:stacks].stamp
      else
        if(args[:refresh_every])
          cache.apply_limit(:stacks, args[:refresh_every].to_i)
        end
        trigger_stack_update!(args)
      end
      if(@memo[:stacks].value)
        @memo[:stacks].value.find_all do |s|
          status.include?(s['StackStatus'])
        end
      else
        []
      end
    end

    def trigger_stack_update!(args={})
      if(@memo[:stacks].update_allowed? || args[:force_refresh])
        trigger_population = false
        @memo.locked_action(:stacks_lock) do
          if(@memo[:stacks].set?)
            @memo[:stacks].restamp!
          else
            @memo[:stacks].value = []
          end
          trigger_population = true
        end
        if(trigger_population)
          long_running_job(:stacks) do
            logger.info "Populating full cloudformation list from remote end point (#{Thread.current.inspect})"
            @memo.locked_action(:stacks_lock) do
              stack_result = throttleable do
                aws(:cloud_formation).describe_stacks.body['Stacks']
              end
              if(stack_result)
                @memo[:stacks].value = stack_result
              end
              lookup_map_set(Hash[stack_result.map{|s| [s['StackName'], s['StackId']]}])
              # Force preload
              stack(*stack_result.map{|s| s['StackName']})
            end
            logger.info "Full cloudformation list from remote end point complete (#{Thread.current.inspect})"
          end
        end
      end
    end

    def throttleable
      if(@throttled.size > 0)
        if(Time.now.to_i - @throttled.last < Time.now.to_i - @throttled.size * 15)
          logger.error "Currently being throttled. Not running request! (#{@throttled.size} throttle size)"
          return nil
        end
      end
      begin
        result = yield
        @throttled.clear
        result
      rescue Fog::Service::Error => e
        if(e.message == 'Throttling => Rate exceeded')
          logger.error "Remote end point is is currently throttling. Rate has been exceeded."
          @throttled << Time.now.to_i
        end
        nil
      end
    end

    def long_running_job(name)
      if(@disconnect_long_jobs)
        logger.debug "Disconnected long running jobs enabled. Starting: #{name}"
        lock_key = "long_jobs_lock_#{name}".to_sym
        @memo.init(lock_key, :lock)
        Thread.new do
          @memo.locked_action(lock_key) do
            begin
              logger.info "Long running job started disconnected (#{name})"
              yield
            rescue => e
              logger.error "Long running job failure (#{name}): #{e.class} - #{e}\n#{e.backtrace.join("\n")}"
            end
          end
        end
      else
        logger.debug "Disconnected long running jobs disabled. Starting #{name} inline"
        yield
      end
    end

    def name_from_stack_id(s_id)
      lookup_map.key(s_id) ||
        raise(IndexError.new("Failed to locate stack with ID: #{s_id}"))
    end

    def id_from_stack_name(name)
      lookup_map[name] ||
        raise(IndexError.new("Failed to locate stack with name: #{name}"))
    end

    def stack(*names)
      direct_load = names.delete(:ignore_seeds)
      uncached_stacks = []
      result = names.map do |name|
        [name, name.start_with?('arn:') || direct_load ? name : id_from_stack_name(name)]
      end.map do |name, s_id|
        unless(@local[:stacks][s_id])
          uncached_stacks << {:name => name, :id => s_id}
        end
        @local[:stacks][s_id]
      end
      load_stack_cache!(uncached_stacks, direct_load)
      names.size == 1 ? result.first : result.compact
    end

    def load_stack_cache!(stack_loads, direct_load = false)
      long_running_job(:cache_stack_loader) do
        stks = stacks unless direct_load
        stack_loads.each do |stack_info|
          unless(direct_load)
            seed = stks.detect do |stk|
              stk['StackId'] == stack_info[:id]
            end
          end
          if(seed)
            logger.debug "Requested stack (#{stack_info[:name]}) loaded via cached seed"
          else
            logger.debug "Requested stack (#{stack_info[:name]}) loaded directly with no seed"
          end
          @local[:stacks][stack_info[:id]] = Stack.new(stack_info[:name], self, seed)
        end
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
