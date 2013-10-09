require 'digest/sha2'

module KnifeCloudformation
  class Cache

    class << self

      def configure(type, args={})
        type = type.to_sym
        case type
        when :redis
          require 'redis-objects'
          Redis::Objects.redis = Redis.new(args)
        when :local
        else
          raise TypeError.new("Unsupported caching type: #{type}")
        end
        enable(type)
      end

      def enable(type)
        @type = type.to_sym
      end

      def type
        @type || :local
      end

      def time_check_allow?(key, stamp)
        Time.now.to_i - stamp.to_i > apply_limit(key)
      end

      def apply_limit(kind, seconds=nil)
        @apply_limit ||= {}
        if(seconds)
          @apply_limit[kind.to_sym] = seconds.to_i
        end
        @apply_limit[kind.to_sym].to_i
      end

    end

    attr_reader :key
    attr_reader :direct_store

    def initialize(key)
      if(key.respond_to?(:sort))
        key = key.flatten if key.respond_to?(:flatten)
        key = key.map(&:to_s).sort
      end
      @key = Digest::SHA256.hexdigest(key.to_s)
      @direct_store = {}
    end

    def init(name, kind)
      name = name.to_sym
      unless(@direct_store[name])
        full_name = [key, name.to_s].join('_')
        @direct_store[name] = get_storage(self.class.type, kind, full_name)
      end
      true
    end

    def clear!(*args)
      internal_lock do
        args = @direct_store.keys if args.empty?
        args.each do |key|
          value = @direct_store[key]
          if(value.respond_to?(:clear))
            value.clear
          elsif(value.respond_to?(:value))
            value.value = nil
          end
        end
        yield if block_given?
      end
      true
    end

    def get_storage(store_type, data_type, full_name, args={})
      case store_type.to_sym
      when :redis
        get_redis_storage(data_type, full_name, args)
      when :local
        get_local_storage(data_type, full_name, args)
      else
        raise TypeError.new("Unsupported caching storage type encountered: #{store_type}")
      end
    end

    def get_redis_storage(data_type, full_name, args={})
      case data_type.to_sym
      when :array
        Redis::List.new(full_name, {:marshal => true}.merge(args))
      when :hash
        Redis::HashKey.new(full_name)
      when :value
        Redis::Value.new(full_name, {:marshal => true}.merge(args))
      when :lock
        Redis::Lock.new(full_name, {:expiration => 3, :timeout => 0.1}.merge(args))
      when :stamped
        Stamped.new(full_name.sub("#{key}_", '').to_sym, get_redis_storage(:value, full_name))
      else
        raise TypeError.new("Unsupported caching data type encountered: #{data_type}")
      end
    end

    def get_local_storage(data_type, full_name, args={})
      case data_type.to_sym
      when :array
        []
      when :hash
        {}
      when :value
        LocalValue.new
      when :lock
        LocalLock.new
      when :stamped
        Stamped.new(full_name.sub("#{key}_", '').to_sym, get_local_storage(:value, full_name))
      else
        raise TypeError.new("Unsupported caching data type encountered: #{data_type}")
      end
    end

    def internal_lock
      get_storage(self.class.type, :lock, :internal_access, :timeout => 20).lock do
        yield
      end
    end

    def [](name)
      internal_lock do
        @direct_store[name.to_sym]
      end
    end

    def []=(key, val)
      raise 'Setting backend data is not allowed'
    end

    class LocalValue
      attr_accessor :value
      def initialize(*args)
        @value = nil
      end
    end

    class LocalLock
      def initialize(*args)
      end

      def lock
        yield
      end

      def clear
      end
    end

    class Stamped

      def initialize(name, base)
        @name = name.to_sym
        @base = base
      end

      def value
        if(@base.value.is_a?(Hash))
          @base.value[:value]
        else
          @base.value
        end
      end

      def value=(v)
        @base.value = {:stamp => Time.now.to_i, :value => v}
      end

      def update_allowed?
        @base.value.nil? ||
          Cache.time_check_allow?(@name, @base.value[:stamp])
      end
    end

  end
end
