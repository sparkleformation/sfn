begin
  require 'chef'
rescue LoadError
  $stderr.puts "WARN: Failed to load Chef. Chef specific features will be disabled!"
end
require 'sfn'

module Sfn
  module Utils

    # Stack serialization helper
    class StackExporter

      include Bogo::AnimalStrings
      include Sfn::Utils::JSON

      # default chef environment name
      DEFAULT_CHEF_ENVIRONMENT = '_default'
      # default instance options
      DEFAULT_OPTIONS = Mash.new(
        :chef_popsicle => true,
        :ignored_parameters => ['Environment', 'StackCreator', 'Creator'],
        :chef_environment_parameter => 'Environment'
      )
      # default structure of export payload
      DEFAULT_EXPORT_STRUCTURE = {
        :stack => Mash.new(
          :template => nil,
          :options => {
            :parameters => Mash.new,
            :capabilities => [],
            :notification_topics => []
          }
        ),
        :generator => {
          :timestamp => Time.now.to_i,
          :name => 'SparkleFormation',
          :version => Sfn::VERSION.version,
          :provider => nil
        }
      }

      # @return [Miasma::Models::Orchestration::Stack]
      attr_reader :stack
      # @return [Hash]
      attr_reader :options
      # @return [Hash]
      attr_reader :stack_export

      # Create new instance
      #
      # @param stack [Miasma::Models::Orchestration::Stack]
      # @param options [Hash]
      # @option options [KnifeCloudformation::Provider] :provider
      # @option options [TrueClass, FalseClass] :chef_popsicle freeze run list
      # @option options [Array<String>] :ignored_parameters
      # @option options [String] :chef_environment_parameter
      def initialize(stack, options={})
        @stack = stack
        @options = DEFAULT_OPTIONS.merge(options)
        @stack_export = Smash.new
      end

      # Export stack
      #
      # @return [Hash] exported stack
      def export
        @stack_export = Smash.new(DEFAULT_EXPORT_STRUCTURE).tap do |stack_export|
          [:parameters, :capabilities, :notification_topics].each do |key|
            if(val = stack.send(key))
              stack_export[:stack][key] = val
            end
          end
          stack_export[:stack][:template] = stack.template
          stack_export[:generator][:timestamp] = Time.now.to_i
          stack_export[:generator][:provider] = stack.provider.connection.provider
          if(chef_popsicle? && defined?(Chef))
            freeze_runlists(stack_export)
          end
          remove_ignored_parameters(stack_export)
          stack_export[:stack][:template] = _to_json(
            stack_export[:stack][:template]
          )
        end
      end

      # Provide query methods on options hash
      #
      # @param args [Object] argument list
      # @return [Object]
      def method_missing(*args)
        m = args.first.to_s
        if(m.end_with?('?') && options.has_key?(k = m.sub('?', '').to_sym))
          !!options[k]
        else
          super
        end
      end

      protected

      # Remove parameter values from export that are configured to be
      # ignored
      #
      # @param export [Hash] stack export
      # @return [Hash]
      def remove_ignored_parameters(export)
        options[:ignored_parameters].each do |param|
          if(export[:stack][:options][:parameters])
            export[:stack][:options][:parameters].delete(param)
          end
        end
        export
      end

      # Environment name to use when interacting with Chef
      #
      # @param export [Hash] current export state
      # @return [String] environment name
      def chef_environment_name(export)
        if(chef_environment_parameter?)
          name = export[:stack][:options][:parameters][options[:chef_environment_parameter]]
        end
        name || DEFAULT_CHEF_ENVIRONMENT
      end

      # @return [Chef::Environment]
      def environment
        unless(@env)
          @env = Chef::Environment.load('_default')
        end
        @env
      end

      # Find latest available cookbook version within
      # the configured environment
      #
      # @param cookbook [String] name of cookbook
      # @return [Chef::Version]
      def allowed_cookbook_version(cookbook)
        restriction = environment.cookbook_versions[cookbook]
        requirement = Gem::Requirement.new(restriction)
        Chef::CookbookVersion.available_versions(cookbook).detect do |v|
          requirement.satisfied_by?(Gem::Version.new(v))
        end
      end

      # Extract the runlist item. Fully expands roles and provides
      # version pegged runlist.
      #
      # @param item [Chef::RunList::RunListItem, Array<String>]
      # @return [Hash] new chef configuration hash
      # @note this will expand all roles
      def extract_runlist_item(item)
        rl_item = item.is_a?(Chef::RunList::RunListItem) ? item : Chef::RunList::RunListItem.new(item)
        static_content = Mash.new(:run_list => [])
        if(rl_item.recipe?)
          cookbook, recipe = rl_item.name.split('::')
          peg_version = allowed_cookbook_version(cookbook)
          static_content[:run_list] << "recipe[#{[cookbook, recipe || 'default'].join('::')}@#{peg_version}]"
        elsif(rl_item.role?)
          role = Chef::Role.load(rl_item.name)
          role.run_list.each do |item|
            static_content = Chef::Mixin::DeepMerge.merge(static_content, extract_runlist_item(item))
          end
          static_content = Chef::Mixin::DeepMerge.merge(
            static_content, Chef::Mixin::DeepMerge.merge(role.default_attributes, role.override_attributes)
          )
        else
          raise TypeError.new("Unknown chef run list item encountered: #{rl_item.inspect}")
        end
        static_content
      end

      # Expand any detected chef run lists and freeze them within the
      # stack template
      #
      # @param first_run [Hash] chef first run hash
      # @return [Hash]
      def unpack_and_freeze_runlist(first_run)
        extracted_runlists = first_run['run_list'].map do |item|
          extract_runlist_item(cf_replace(item))
        end
        first_run.delete('run_list')
        first_run.replace(
          extracted_runlists.inject(first_run) do |memo, first_run_item|
            Chef::Mixin::DeepMerge.merge(memo, first_run_item)
          end
        )
      end

      # Freeze chef run lists
      #
      # @param exported [Hash] stack export
      # @return [Hash]
      def freeze_runlists(exported)
        first_runs = locate_runlists(exported)
        first_runs.each do |first_run|
          unpack_and_freeze_runlist(first_run)
        end
        exported
      end

      # Locate chef run lists within data collection
      #
      # @param thing [Enumerable] collection from export
      # @return [Enumerable] updated collection from export
      def locate_runlists(thing)
        result = []
        case thing
        when Hash
          if(thing['content'] && thing['content']['run_list'])
            result << thing['content']
          else
            thing.each do |k,v|
              result += locate_runlists(v)
            end
          end
        when Array
          thing.each do |v|
            result += locate_runlists(v)
          end
        end
        result
      end

      # Apply cloudformation function to data
      #
      # @param hsh [Object] stack template item
      # @return [Object]
      def cf_replace(hsh)
        if(hsh.is_a?(Hash))
          case hsh.keys.first
          when 'Fn::Join'
            cf_join(*hsh.values.first)
          when 'Ref'
            cf_ref(hsh.values.first)
          else
            hsh
          end
        else
          hsh
        end
      end

      # Apply Ref function
      #
      # @param ref_name [Hash]
      # @return [Object] value in parameters
      def cf_ref(ref_name)
        if(stack.parameters.has_key?(ref_name))
          stack.parameters[ref_name]
        else
          raise KeyError.new("No parameter found with given reference name (#{ref_name}). " <<
            "Only parameter based references supported!")
        end
      end

      # Apply Join function
      #
      # @param delim [String] join delimiter
      # @param args [String, Hash] items to join
      # @return [String]
      def cf_join(delim, args)
        args.map do |arg|
          if(arg.is_a?(Hash))
            cf_replace(arg)
          else
            arg.to_s
          end
        end.join(delim)
      end
    end
  end
end
