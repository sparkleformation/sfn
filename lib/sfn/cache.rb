require "digest/sha2"
require "thread"
require "sfn"

module Sfn
  # Data caching helper
  class Cache
    class << self

      # Configure the caching approach to use
      #
      # @param type [Symbol] :redis or :local
      # @param args [Hash] redis connection arguments if used
      def configure(type, args = {})
        type = type.to_sym
        case type
        when :redis
          begin
            require "redis-objects"
          rescue LoadError
            $stderr.puts "The `redis-objects` gem is required for Cache support!"
            raise
          end
          @_pid = Process.pid
          Redis::Objects.redis = Redis.new(args)
        when :local
        else
          raise TypeError.new("Unsupported caching type: #{type}")
        end
        enable(type)
      end

      # Set enabled caching type
      #
      # @param type [Symbol]
      # @return [Symbol]
      def enable(type)
        @type = type.to_sym
      end

      # @return [Symbol] type of caching enabled
      def type
        @type || :local
      end

      # Set/get time limit on data type
      #
      # @param kind [String, Symbol] data type
      # @param seconds [Integer]
      # return [Integer] seconds
      def apply_limit(kind, seconds = nil)
        @apply_limit ||= {}
        if seconds
          @apply_limit[kind.to_sym] = seconds.to_i
        end
        @apply_limit[kind.to_sym].to_i
      end

      # @return [Hash] default limits
      def default_limits
        (@apply_limit || {}).dup
      end

      # Ping the redis connection and reconnect if dead
      def redis_ping!
        if (@_pid && @_pid != Process.pid) || !Redis::Objects.redis.connected?
          Redis::Objects.redis.client.reconnect
          @_pid = Process.pid
        end
      end
    end

    # @return [String] custom key for this cache
    attr_reader :key

    # Create new instance
    #
    # @param key [String, Array]
    def initialize(key)
      if key.respond_to?(:sort)
        key = key.flatten if key.respond_to?(:flatten)
        key = key.map(&:to_s).sort
      end
      @key = Digest::SHA256.hexdigest(key.to_s)
      @apply_limit = self.class.default_limits
    end

    # Initialize a new data type
    #
    # @param name [Symbol] name of data
    # @param kind [Symbol] data type
    # @param args [Hash] options for data type
    def init(name, kind, args = {})
      get_storage(self.class.type, kind, name, args)
      true
    end

    # @return [Hash] data registry
    def registry
      get_storage(self.class.type, :hash, "registry_#{key}")
    end

    # Clear data
    #
    # @param args [Symbol] list of names to delete
    # @return [TrueClass]
    # @note clears all data if no names provided
    def clear!(*args)
      internal_lock do
        args = registry.keys if args.empty?
        args.each do |key|
          value = self[key]
          if value.respond_to?(:clear)
            value.clear
          elsif value.respond_to?(:value)
            value.value = nil
          end
          registry.delete(key)
        end
        yield if block_given?
      end
      true
    end

    # Fetch item from storage
    #
    # @param store_type [Symbol]
    # @param data_type [Symbol]
    # @param name [Symbol] name of data
    # @param args [Hash] options for underlying storage
    # @return [Object]
    def get_storage(store_type, data_type, name, args = {})
      full_name = "#{key}_#{name}"
      result = nil
      case store_type.to_sym
      when :redis
        result = get_redis_storage(data_type, full_name.to_s, args)
      when :local
        @_local_cache ||= {}
        unless @_local_cache[full_name.to_s]
          @_local_cache[full_name.to_s] = get_local_storage(data_type, full_name.to_s, args)
        end
        result = @_local_cache[full_name.to_s]
      else
        raise TypeError.new("Unsupported caching storage type encountered: #{store_type}")
      end
      unless full_name == "#{key}_registry_#{key}"
        registry[name.to_s] = data_type
      end
      result
    end

    # Fetch item from redis storage
    #
    # @param data_type [Symbol]
    # @param full_name [Symbol]
    # @param args [Hash]
    # @return [Object]
    def get_redis_storage(data_type, full_name, args = {})
      self.class.redis_ping!
      case data_type.to_sym
      when :array
        Redis::List.new(full_name, {:marshal => true}.merge(args))
      when :hash
        Redis::HashKey.new(full_name)
      when :value
        Redis::Value.new(full_name, {:marshal => true}.merge(args))
      when :lock
        Redis::Lock.new(full_name, {:expiration => 60, :timeout => 0.1}.merge(args))
      when :stamped
        Stamped.new(full_name.sub("#{key}_", "").to_sym, get_redis_storage(:value, full_name), self)
      else
        raise TypeError.new("Unsupported caching data type encountered: #{data_type}")
      end
    end

    # Fetch item from local storage
    #
    # @param data_type [Symbol]
    # @param full_name [Symbol]
    # @param args [Hash]
    # @return [Object]
    # @todo make proper singleton for local storage
    def get_local_storage(data_type, full_name, args = {})
      @storage ||= {}
      @storage[full_name] ||= case data_type.to_sym
                              when :array
                                []
                              when :hash
                                {}
                              when :value
                                LocalValue.new
                              when :lock
                                LocalLock.new(full_name, {:expiration => 60, :timeout => 0.1}.merge(args))
                              when :stamped
                                Stamped.new(full_name.sub("#{key}_", "").to_sym, get_local_storage(:value, full_name), self)
                              else
                                raise TypeError.new("Unsupported caching data type encountered: #{data_type}")
                              end
    end

    # Execute block within internal lock
    #
    # @return [Object] result of yield
    # @note for internal use
    def internal_lock
      get_storage(self.class.type, :lock, :internal_access, :timeout => 20, :expiration => 120).lock do
        yield
      end
    end

    # Fetch data
    #
    # @param name [String, Symbol]
    # @return [Object, NilClass]
    def [](name)
      if kind = registry[name.to_s]
        get_storage(self.class.type, kind, name)
      else
        nil
      end
    end

    # Set data
    #
    # @param key [Object]
    # @param val [Object]
    # @note this will never work, thus you should never use it
    def []=(key, val)
      raise "Setting backend data is not allowed"
    end

    # Check if cache time has expired
    #
    # @param key [String, Symbol] value key
    # @param stamp [Time, Integer]
    # @return [TrueClass, FalseClass]
    def time_check_allow?(key, stamp)
      Time.now.to_i - stamp.to_i > apply_limit(key)
    end

    # Apply time limit for data type
    #
    # @param kind [String, Symbol] data type
    # @param seconds [Integer]
    # return [Integer]
    def apply_limit(kind, seconds = nil)
      @apply_limit ||= {}
      if seconds
        @apply_limit[kind.to_sym] = seconds.to_i
      end
      @apply_limit[kind.to_sym].to_i
    end

    # Perform action within lock
    #
    # @param lock_name [String, Symbol] name of lock
    # @param raise_on_locked [TrueClass, FalseClass] raise execption if lock wait times out
    # @return [Object] result of yield
    def locked_action(lock_name, raise_on_locked = false)
      begin
        self[lock_name].lock do
          yield
        end
      rescue => e
        if e.class.to_s.end_with?("Timeout")
          raise if raise_on_locked
        else
          raise
        end
      end
    end

    # Simple value for memory cache
    class LocalValue
      # @return [Object] value
      attr_accessor :value

      def initialize(*args)
        @value = nil
      end
    end

    # Simple lock for memory cache
    class LocalLock
      class LocalLockTimeout < RuntimeError
      end

      # @return [Symbol] key name
      attr_reader :_key
      # @return [Numeric] timeout
      attr_reader :_timeout
      # @return [Mutex] underlying lock
      attr_reader :_lock

      # Create new instance
      #
      # @param name [Symbol] name of lock
      # @param args [Hash]
      # @option args [Numeric] :timeout
      def initialize(name, args = {})
        @_key = name
        @_timeout = args.fetch(:timeout, -1).to_f
        @_lock = Mutex.new
      end

      # Aquire lock and yield
      #
      # @yield block to execute within lock
      # @return [Object] result of yield
      def lock
        locked = false
        attempt_start = Time.now.to_f
        while (!locked && (_timeout < 0 || Time.now.to_f - attempt_start < _timeout))
          locked = _lock.try_lock
        end
        if locked
          begin
            yield
          ensure
            _lock.unlock if _lock.locked?
          end
        else
          if defined?(Redis)
            raise Redis::Lock::LockTimeout.new "Timeout on lock #{_key} exceeded #{_timeout} sec"
          else
            raise LocalLockTimeout.new "Timeout on lock #{_key} exceeded #{_timeout} sec"
          end
        end
      end

      # Clear the lock
      #
      # @note this is a noop
      def clear
        # noop
      end
    end

    # Wrapper to auto stamp values
    class Stamped

      # Create new instance
      #
      # @param name [String, Symbol]
      # @param base [Redis::Value, LocalValue]
      # @param cache [Cache]
      def initialize(name, base, cache)
        @name = name.to_sym
        @base = base
        @cache = cache
      end

      # @return [Object] value stored
      def value
        @base.value[:value] if set?
      end

      # Store value and update timestamp
      #
      # @param v [Object] value
      # @return [Object]
      def value=(v)
        @base.value = {:stamp => Time.now.to_f, :value => v}
        v
      end

      # @return [TrueClass, FalseClass] is value set
      def set?
        @base.value.is_a?(Hash)
      end

      # @return [Float] timestamp of last set (or 0.0 if unset)
      def stamp
        set? ? @base.value[:stamp] : 0.0
      end

      # Force a timestamp update
      def restamp!
        self.value = value
      end

      # @return [TrueClass, FalseClass] update is allowed based on stamp and limits
      def update_allowed?
        !set? || @cache.time_check_allow?(@name, @base.value[:stamp])
      end
    end
  end
end
