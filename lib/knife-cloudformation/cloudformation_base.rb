require 'chef/knife'
require 'knife-cloudformation/utils'
require 'knife-cloudformation/aws_commons'

module KnifeCloudformation

  module KnifeBase

    module InstanceMethods

      def aws
        self.class.con(ui)
      end

      def _debug(e, *args)
        if(ENV['DEBUG'])
          ui.fatal "Exception information: #{e.class}: #{e}\n#{e.backtrace.join("\n")}\n"
          args.each do |string|
            ui.fatal string
          end
        end
      end

      def stack(name)
        self.class.con(ui).stack(name, :ignore_seeds)
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

      def poll_stack(name)
        knife_events = Chef::Knife::CloudformationEvents.new
        knife_events.name_args.push(name)
        Chef::Config[:knife][:cloudformation][:poll] = true
        knife_events.run
      end

      def things_output(stack, things, what, *args)
        unless(args.include?(:no_title))
          output = aws.get_titles(things, :format => true, :attributes => allowed_attributes)
        else
          output = []
        end
        columns = allowed_attributes.size
        output += aws.process(things, :flat => true, :attributes => allowed_attributes)
        output.compact.flatten
        if(output.empty?)
          ui.warn 'No information found' unless args.include?(:ignore_empty_output)
        else
          ui.info "#{what.to_s.capitalize} for stack: #{ui.color(stack, :bold)}" if stack
          ui.info "#{ui.list(output, :uneven_columns_across, columns)}"
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

    end

    module ClassMethods

      def con(ui=nil)
        unless(@common)
          @common = KnifeCloudformation::AwsCommons.new(
            :ui => ui,
            :fog => {
              :aws_access_key_id => _key,
              :aws_secret_access_key => _secret,
              :region => _region
            }
          )
        end
        @common
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

    class << self
      def included(klass)
        klass.instance_eval do

          extend KnifeCloudformation::KnifeBase::ClassMethods
          include KnifeCloudformation::KnifeBase::InstanceMethods
          include KnifeCloudformation::Utils::JSON
          include KnifeCloudformation::Utils::AnimalStrings

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


          # Populate up the hashes so they are available for knife config
          # with issues of nils
          ['knife.cloudformation.credentials', 'knife.cloudformation.options'].each do |stack|
            stack.split('.').inject(Chef::Config) do |memo, item|
              memo[item.to_sym] = Mash.new unless memo[item.to_sym]
              memo[item.to_sym]
            end
          end

          Chef::Config[:knife][:cloudformation] ||= Mash.new

        end
      end
    end
  end

end
