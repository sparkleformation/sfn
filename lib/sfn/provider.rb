require 'logger'
require 'sfn'

module Sfn
  # Remote provider interface
  class Provider

    include Bogo::AnimalStrings

    # Minimum number of seconds to wait before re-expanding in
    # progress stack
    STACK_EXPAND_INTERVAL = 45

    # Default interval for refreshing stack list in cache
    STACK_LIST_INTERVAL = 120

    # @return [Miasma::Models::Orchestration]
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
    # @option args [Hash] :miasma miasma connection hash
    # @option args [Cache] :cache
    # @option args [TrueClass, FalseClass] :async fetch stacks async (defaults true)
    # @option args [Logger] :logger use custom logger
    # @option args [Numeric] :stack_expansion_interval interval to wait between stack data expands
    # @option args [Numeric] :stack_list_interval interval to wait between stack list refresh
    def initialize(args={})
      args = args.to_smash
      unless(args.get(:miasma, :provider))
        best_guess = (args[:miasma] || {}).keys.group_by do |key|
          key.to_s.split('_').first
        end.sort do |x, y|
          y.size <=> x.size
        end.first
        if(best_guess)
          provider = best_guess.first.to_sym
        else
          raise ArgumentError.new 'Cannot auto determine :provider value for credentials'
        end
      else
        provider = args[:miasma].delete(:provider).to_sym
      end
      if(provider == :aws)
        if(args[:miasma][:region])
          args[:miasma][:aws_region] = args[:miasma].delete(:region)
        end
      end
      if(ENV['DEBUG'].to_s.downcase == 'true')
        log_to = STDOUT
      else
        if(Gem.win_platform?)
          log_to = 'NUL'
        else
          log_to = '/dev/null'
        end
      end
      @logger = args.fetch(:logger, Logger.new(log_to))
      @stack_expansion_interval = args.fetch(:stack_expansion_interval, STACK_EXPAND_INTERVAL)
      @stack_list_interval = args.fetch(:stack_list_interval, STACK_LIST_INTERVAL)
      @connection = Miasma.api(
        :provider => provider,
        :type => :orchestration,
        :credentials => args[:miasma]
      )
      @cache = args.fetch(:cache, Cache.new(:local))
      @async = args.fetch(:async, true)
      @miamsa_args = args[:miasma].dup
      cache.init(:stacks_lock, :lock, :timeout => 0.1)
      cache.init(:stacks, :stamped)
      cache.init(:stack_expansion_lock, :lock, :timeout => 0.1)
      if(args.fetch(:fetch, false))
        async ? update_stack_list! : fetch_stacks
      end
    end

    # @return [Miasma::Orchestration::Stacks]
    def stacks
      connection.stacks.from_json(cached_stacks)
    end

    # @return [String] json representation of cached stacks
    def cached_stacks
      fetch_stacks unless @initial_fetch_complete
      value = cache[:stacks].value
      value ? MultiJson.dump(MultiJson.load(value).values) : '[]'
    end

    # @return [Miasma::Orchestration::Stack, NilClass]
    def stack(stack_id)
      stacks.get(stack_id)
    end

    # Store stack attribute changes
    #
    # @param stack_id [String]
    # @param stack_attributes [Hash]
    # @return [TrueClass]
    def save_expanded_stack(stack_id, stack_attributes)
      current_stacks = MultiJson.load(cached_stacks)
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
      current_stacks = MultiJson.load(cached_stacks)
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
    # @param stack [Miasma::Models::Orchestration::Stack]
    def expand_stack(stack)
      logger.info "Stack expansion requested (#{stack.id})"
      if((stack.in_progress? && Time.now.to_i - stack.attributes['Cached'].to_i > stack_expansion_interval) ||
          !stack.attributes['Cached'])
        begin
          expanded = false
          cache.locked_action(:stack_expansion_lock) do
            expanded = true
            stack.reload
            stack.data['Cached'] = Time.now.to_i
          end
          if(expanded)
            save_expanded_stack(stack.id, stack.to_json)
          end
        rescue => e
          logger.error "Stack expansion failed (#{stack.id}) - #{e.class}: #{e}"
        end
      else
        logger.info "Stack has been cached within expand interval. Expansion prevented. (#{stack.id})"
      end
    end

    # Request stack information and store in cache
    #
    # @return [TrueClass]
    def fetch_stacks
      cache.locked_action(:stacks_lock) do
        logger.info "Lock aquired for stack update. Requesting stacks from upstream. (#{Thread.current})"
        stacks = Hash[
          connection.stacks.reload.all.map do |stack|
            [stack.id, stack.attributes]
          end
        ]
        if(cache[:stacks].value)
          existing_stacks = MultiJson.load(cache[:stacks].value)
          # Force common types
          stacks = MultiJson.load(MultiJson.dump(stacks))
          # Remove stacks that have been deleted
          stale_ids = existing_stacks.keys - stacks.keys
          stacks = existing_stacks.to_smash.deep_merge(stacks)
          stale_ids.each do |stale_id|
            stacks.delete(stale_id)
          end
        end
        cache[:stacks].value = stacks.to_json
        logger.info 'Stack list has been updated from upstream and cached locally'
      end
      @initial_fetch_complete = true
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
    # @return [Miasma::Model]
    def service_for(service)
      connection.api_for(service)
    end

  end
end

# Release the monkeys!
Sfn::MonkeyPatch::Stack
