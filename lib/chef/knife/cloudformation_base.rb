require 'chef/knife'

class Chef
  class Knife

    # Populate up the hashes so they are available for knife config
    # with issues of nils
    ['knife.cloudformation.credentials', 'knife.cloudformation.options'].each do |stack|
      stack.split('.').inject(Chef::Config) do |memo, item|
        memo[item.to_sym] = Mash.new unless memo[item.to_sym]
        memo[item.to_sym]
      end
    end
    
    Chef::Config[:knife][:cloudformation] ||= Mash.new
    
    module CloudformationDefault
      class << self
        def included(klass)
          klass.instance_eval do
            deps do
              require 'fog'
              Chef::Config[:knife][:cloudformation] ||= Mash.new
              Chef::Config[:knife][:cloudformation][:credentials] ||= Mash.new
              Chef::Config[:knife][:cloudformation][:options] ||= Mash.new
            end

            option(:key,
              :short => '-K KEY',
              :long => '--key KEY',
              :description => 'AWS access key id',
              :proc => lambda {|val|
                Chef::Config[:knife][:cloudformation][:credentials][:key] = val
              }
            )
            option(:secret,
              :short => '-S SECRET',
              :long => '--secret SECRET',
              :description => 'AWS secret access key',
              :proc => lambda {|val|
                Chef::Config[:knife][:cloudformation][:credentials][:secret] = val
              }
            )
            option(:region,
              :short => '-r REGION',
              :long => '--region REGION',
              :description => 'AWS region',
              :proc => lambda {|val|
                Chef::Config[:knife][:cloudformation][:credentials][:region] = val
              }
            )
          end
        end
      end
    end

    class CloudformationBase < Knife

      class << self
        def aws_con
          @connection ||= Fog::AWS::CloudFormation.new(
            :aws_access_key_id => _key,
            :aws_secret_access_key => _secret,
            :region => _region
          )
        end

        def _key
          Chef::Config[:knife][:cloudformation][:credentials][:key] ||
            Chef::Config[:knife][:aws_access_key_id]
        end

        def _secret
          Chef::Config[:knife][:cloudformation][:credentials][:secret] ||
            Chef::Config[:knife][:aws_secret_access_key]
        end

        def _region
          Chef::Config[:knife][:cloudformation][:credentials][:region] ||
            Chef::Config[:knife][:region]
        end

      end

      def _debug(e, *args)
        if(ENV['DEBUG'])
          ui.fatal "Exception information: #{e.class}: #{e}\n#{e.backtrace.join("\n")}\n"
          args.each do |string|
            ui.fatal string
          end
        end
      end

      def aws_con
        self.class.aws_con
      end
      
      def stack_status(name)
        aws_con.describe_stacks('StackName' => name).body['Stacks'].first['StackStatus']
      end

      def get_titles(thing, format=false)
        unless(@titles)
          attrs = allowed_attributes
          if(attrs.empty?)
            hash = thing.is_a?(Array) ? thing.first : thing
            hash ||= {}
            attrs = hash.keys
          end
          @titles = attrs.map do |key|
            next unless attribute_allowed?(key)
            key.gsub(/([a-z])([A-Z])/, '\1 \2')
          end.compact
        end
        if(format)
          @titles.map{|s| ui.color(s, :bold)}
        else
          @titles
        end
      end

      def process(things)
        @event_ids ||= []
        things.reverse.map do |thing|
          next if @event_ids.include?(thing['EventId'])
          @event_ids.push(thing['EventId']).compact!
          get_titles(thing).map do |key|
            thing[key.gsub(' ', '')].to_s
          end
        end.flatten.compact
      end

      def allowed_attributes
        Chef::Config[:knife][:cloudformation][:attributes] || default_attributes
      end

      def default_attributes
        %w(Timestamp StackName StackId)
      end

      def attribute_allowed?(attr)
        config[:all_attributes] || allowed_attributes.include?(attr)
      end

      def things_output(stack, things, what)
        output = get_titles(things, :format)
        output += process(things)
        output.compact.flatten
        if(output.empty?)
          ui.warn 'No information found'
        else
          ui.info "#{what.to_s.capitalize} for stack: #{ui.color(stack, :bold)}" if stack
          ui.info "#{ui.list(output, :uneven_columns_across, get_titles(things).size)}\n"
        end
      end

      def get_things(stack=nil, message=nil)
        begin
          yield
        rescue => e
          ui.fatal "#{message || 'Failed to retrieve information'}#{" for requested stack: #{stack}" if stack}"
          ui.fatal "Reason: #{e}"
          _debug(e)
          exit 1
        end
      end

      def try_json_compat
        begin
          require 'chef/json_compat'
        rescue
        end
        defined?(Chef::JSONCompat)
      end
      
      def _to_json(thing)
        if(try_json_compat)
          Chef::JSONCompat.to_json(thing)
        else
          JSON.dump(thing)
        end
      end

      def _from_json(thing)
        if(try_json_compat)
          Chef::JSONCompat.from_json(thing)
        else
          JSON.read(thing)
        end
      end

      def _format_json(thing)
        thing = _from_json(thing) if thing.is_a?(String)
        if(try_json_compat)
          Chef::JSONCompat.to_json_pretty(thing)
        else
          JSON.pretty_generate(thing)
        end
      end
    end
  end
end
