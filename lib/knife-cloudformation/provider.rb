require 'fog'
require 'chef/mash'
require 'chef/mixin/deep_merge'
require 'knife-cloudformation'

module KnifeCloudformation
  # Remote provider interface
  class Provider

    include KnifeCloudformation::Utils::AnimalStrings

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

    # Create new instance
    #
    # @param args [Hash]
    # @option args [Hash] :fog fog connection hash
    # @option args [Cache] :cache
    # @option args [TrueClass, FalseClass] :async fetch stacks async (defaults true)
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
      @connection = Fog::Orchestration.new(args[:fog])
      @cache = args.fetch(:cache, Cache.new(:local))
      @async = args.fetch(:async, true)
      @fog_args = args[:fog].dup
      cache.init(:stacks_lock, :lock)
      cache.init(:stacks, :stamped)
      cache.init(:stack_expansion_lock, :lock)
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
      cache.locked_action(:stacks_lock) do
        val = current_stacks.delete(stack_id)
        cache[:stacks].value = MultiJson.dump(current_stacks)
        !!val
      end
    end

    # Expand all lazy loaded attributes within stack
    #
    # @param stack [Fog::Orchestration::Stack]
    def expand_stack(stack)
      if((stack.in_progress? && Time.now.to_i - stack.attributes['Cached'].to_i > 20) ||
          !stack.attributes['Cached'])
        cache.locked_action(:stack_expansion_lock) do
          stack.reload
          stack.events
          stack.resources
          stack.template
          stack.attributes['Cached'] = Time.now.to_i
        end
        save_expanded_stack(stack.id, stack.attributes)
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
        stacks = Hash[
          connection.stacks(:filters => format_status).map do |stack|
            [stack.id, stack.attributes]
          end
        ]
        if(cache[:stacks].value)
          existing_stacks = MultiJson.load(cache[:stacks].value)
          # Force common types
          stacks = MultiJson.load(MultiJson.dump(stacks))
          stacks = Chef::Mixin::DeepMerge.merge(existing_stacks, stacks)
        end
        cache[:stacks].value = stacks.to_json
      end
      true
    end

    # Start async stack list update
    #
    # @return [TrueClass, FalseClass]
    def update_stack_list!
      if(updater.nil? || !updater.alive?)
        self.updater = Thread.new{
          fetch_stacks
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
