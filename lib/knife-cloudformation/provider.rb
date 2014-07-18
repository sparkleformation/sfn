require 'fog'
require 'chef/mash'
require 'logger'
require 'chef/mixin/deep_merge'
require 'knife-cloudformation'

module KnifeCloudformation
  # Remote provider interface
  class Provider

    include KnifeCloudformation::Utils::AnimalStrings

    # Minimum number of seconds to wait before re-expanding in
    # progress stack
    STACK_EXPAND_INTERVAL = 45

    # Default interval for refreshing stack list in cache
    STACK_LIST_INTERVAL = 120

    # Default stack status filters
    DEFAULT_STACK_STATUS = {
      Fog::AWS::CloudFormation::Real => {
        :status => %w(
          CREATE_IN_PROGRESS CREATE_COMPLETE CREATE_FAILED
          ROLLBACK_IN_PROGRESS ROLLBACK_COMPLETE ROLLBACK_FAILED
          UPDATE_IN_PROGRESS UPDATE_COMPLETE UPDATE_COMPLETE_CLEANUP_IN_PROGRESS
          UPDATE_ROLLBACK_IN_PROGRESS UPDATE_ROLLBACK_FAILED
          UPDATE_ROLLBACK_COMPLETE_CLEANUP_IN_PROGRESS UPDATE_ROLLBACK_COMPLETE
          DELETE_IN_PROGRESS DELETE_FAILED
        ),
        :formatter => lambda{|statuses|
          args = statuses.size.times.map do |i|
            idx = i + 1
            ["StackStatusFilter.member.#{idx}", statuses[i]]
          end
          Hash[args]
        }
      }
    }

    # @return [Fog::Orchestration]
    attr_reader :connection
    # @return [Cache]
    attr_reader :cache
    # @return [Thread, NilClass] stack list updater
    attr_accessor :updater
    # @return [TrueClass, FalseClass] async updates
    attr_reader :async
    # @return [Logger, NilClass] logger in use
    attr_reader :logger
    # @return [Numeric] interval between stack expansions
    attr_reader :stack_expansion_interval
    # @return [Numeric] interval between stack list updates
    attr_reader :stack_list_interval

    # Create new instance
    #
    # @param args [Hash]
    # @option args [Hash] :fog fog connection hash
    # @option args [Cache] :cache
    # @option args [TrueClass, FalseClass] :async fetch stacks async (defaults true)
    # @option args [Logger] :logger use custom logger
    # @option args [Numeric] :stack_expansion_interval interval to wait between stack data expands
    # @option args [Numeric] :stack_list_interval interval to wait between stack list refresh
    def initialize(args={})
      unless(args[:fog][:provider])
        best_guess = args[:fog].keys.group_by do |key|
          key.to_s.split('_').first
        end.sort do |x, y|
          y.size <=> x.size
        end.first
        if(best_guess)
          args[:fog][:provider] = best_guess.first
        else
          raise ArgumentError.new 'Cannot auto determine :provider value for credentials'
        end
      end
      @logger = args.fetch(:logger, Logger.new(ENV['DEBUG'] ? STDOUT : '/dev/null'))
      @stack_expansion_interval = args.fetch(:stack_expansion_interval, STACK_EXPAND_INTERVAL)
      @stack_list_interval = args.fetch(:stack_list_interval, STACK_LIST_INTERVAL)
      @connection = Fog::Orchestration.new(args[:fog])
      @cache = args.fetch(:cache, Cache.new(:local))
      @async = args.fetch(:async, true)
      @fog_args = args[:fog].dup
      cache.init(:stacks_lock, :lock, :timeout => 0.1)
      cache.init(:stacks, :stamped)
      cache.init(:stack_expansion_lock, :lock, :timeout => 0.1)
      async ? update_stack_list! : fetch_stacks
    end

    # @return [Fog::Orchestration::Stacks]
    def stacks
      _stacks = connection.service.const_get(:Stacks).
        new(:service => connection).
        load(cached_stacks.values)
      _stacks.map do |_stack|
        _stack._provider(self)
        _stack
      end
      _stacks
    end

    # @return [Hash] cached stacks
    def cached_stacks
      value = cache[:stacks].value
      value ? MultiJson.load(value) : {}
    end

    # @return [Fog::Orchestration::Stack, NilClass]
    def stack(stack_id)
      attributes = cached_stacks[stack_id]
      if(attributes)
        stack = connection.service.const_get(:Stack).new(
          {:service => connection}.merge(attributes)
        )
        stack._provider(self)
        stack.full_expansion!
      end
    end

    # Store stack attribute changes
    #
    # @param stack_id [String]
    # @param stack_attributes [Hash]
    # @return [TrueClass]
    def save_expanded_stack(stack_id, stack_attributes)
      current_stacks = cached_stacks
      cache.locked_action(:stacks_lock) do
        logger.info "Saving expanded stack attributes in cache (#{stack_id})"
        current_stacks[stack_id] = stack_attributes.merge('Cached' => Time.now.to_i)
        cache[:stacks].value = MultiJson.dump(current_stacks)
      end
      true
    end

    # Remove stack from the cache
    #
    # @param stack_id [String]
    # @return [TrueClass, FalseClass]
    def remove_stack(stack_id)
      current_stacks = cached_stacks
      logger.info "Attempting to remove stack from internal cache (#{stack_id})"
      cache.locked_action(:stacks_lock) do
        val = current_stacks.delete(stack_id)
        logger.info "Successfully removed stack from internal cache (#{stack_id})"
        cache[:stacks].value = MultiJson.dump(current_stacks)
        !!val
      end
    end

    # Expand all lazy loaded attributes within stack
    #
    # @param stack [Fog::Orchestration::Stack]
    def expand_stack(stack)
      logger.info "Stack expansion requested (#{stack.id})"
      if((stack.in_progress? && Time.now.to_i - stack.attributes['Cached'].to_i > stack_expansion_interval) ||
          !stack.attributes['Cached'])
        begin
          cache.locked_action(:stack_expansion_lock) do
            expanded = true
            stack.reload
            stack.events
            stack.resources
            stack.template
            stack.attributes['Cached'] = Time.now.to_i
          end
          if(expanded)
            save_expanded_stack(stack.id, stack.attributes)
          end
        rescue => e
          logger.error "Stack expansion failed (#{stack.id}) - #{e.class}: #{e}"
        end
      else
        logger.info "Stack has been cached within expand interval. Expansion prevented. (#{stack.id})"
      end
    end

    # Format status array into option proper option
    #
    # @return [NilClass, Object]
    def format_status(statuses=nil)
      conf = DEFAULT_STACK_STATUS[connection.class]
      if(conf)
        conf[:formatter].call(statuses || conf[:status])
      end
    end

    # Request stack information and store in cache
    #
    # @return [TrueClass]
    def fetch_stacks
      cache.locked_action(:stacks_lock) do
        logger.info "Lock aquired for stack update. Requesting stacks from upstream. (#{Thread.current})"
        stacks = Hash[
          connection.stacks(:filters => format_status).map do |stack|
            [stack.id, stack.attributes]
          end
        ]
        if(cache[:stacks].value)
          existing_stacks = MultiJson.load(cache[:stacks].value)
          # Force common types
          stacks = MultiJson.load(MultiJson.dump(stacks))
          # Remove stacks that have been deleted
          stale_ids = existing_stacks.map(&:id) - stacks.map(&:id)
          stacks = Chef::Mixin::DeepMerge.merge(existing_stacks, stacks)
          stale_ids.each do |stale_id|
            stacks.delete(stale_id)
          end
        end
        cache[:stacks].value = stacks.to_json
        logger.info 'Stack list has been updated from upstream and cached locally'
      end
      true
    end

    # Start async stack list update. Creates thread that loops every
    # `self.stack_list_interval` seconds and refreshes stack list in cache
    #
    # @return [TrueClass, FalseClass]
    def update_stack_list!
      if(updater.nil? || !updater.alive?)
        self.updater = Thread.new{
          loop do
            begin
              fetch_stacks
              sleep(stack_list_interval)
            rescue => e
              logger.error "Failure encountered on stack fetch: #{e.class} - #{e}"
            end
          end
        }
        true
      else
        false
      end
    end

    # Build API connection for service type
    #
    # @param service [String, Symbol]
    # @param args [Hash] optional fog argument hash
    # @return [Fog::Service]
    def service_for(service, args={})
      klass_name = Fog.constants.sort.detect do |symbol|
        snake(symbol) == service.to_sym
      end
      if(klass_name)
        Fog.const_get(klass_name).new(@fog_args.merge(args))
      else
        raise ArgumentError.new("Invalid service name provided. Unable to locate API handler. (#{service})")
      end
    end

  end
end

# Release the monkeys!
KnifeCloudformation::MonkeyPatch::Stack
