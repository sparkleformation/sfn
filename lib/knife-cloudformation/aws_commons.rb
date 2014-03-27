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

    attr_reader :credentials, :stack_items
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
      @stack_items = {}
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

    def clear_cache(*types)
      cache.clear!(*types)
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
        cache[:stacks].stamp
      else
        if(args[:refresh_every])
          cache.apply_limit(:stacks, args[:refresh_every].to_i)
        end
        trigger_stack_update!(args)
      end
      if(cache[:stacks].value)
        cache[:stacks].value.find_all do |s|
          status.include?(s['StackStatus'])
        end
      else
        []
      end
    end

    def trigger_stack_update!(args={})
      if(cache[:stacks].update_allowed? || args[:force_refresh])
        trigger_population = false
        cache.locked_action(:stacks_lock) do
          if(cache[:stacks].set?)
            cache[:stacks].restamp!
          else
            cache[:stacks].value = []
          end
          trigger_population = true
        end
        if(trigger_population)
          long_running_job(:stacks) do
            logger.info "Populating full cloudformation list from remote end point (#{Thread.current.inspect})"
            cache.locked_action(:stacks_lock) do
              stack_result = throttleable do
                aws(:cloud_formation).describe_stacks.body['Stacks']
              end
              if(stack_result)
                cache[:stacks].value = stack_result
              end
            end
            logger.info "Full cloudformation list from remote end point complete (#{Thread.current.inspect})"
            logger.info "Caching stacks into local process (#{Thread.current.inspect})"
            stack(cache[:stacks].value.map{|s| s['StackName']})
            logger.info "Local process stack caching is complete! (#{Thread.current.inspect})"
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
        cache.init(lock_key, :lock)
        Thread.new do
          cache.locked_action(lock_key) do
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

    def stack(*names)
      direct_load = names.delete(:ignore_seeds)
      stks = direct_load ? [] : stacks
      result = names.map do |name|
        unless(stack_items[name])
          seed = stks.detect{|s|s['StackName'] == name}
          stack_items[name] = Stack.new(name, self, seed)
        end
        stack_items[name]
      end.compact
      names.size == 1 ? result.first : result
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
