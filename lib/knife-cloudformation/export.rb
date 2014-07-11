require 'chef'
require 'knife-cloudformation'

module KnifeCloudformation
  class Export

    DEFAULT_OPTIONS = {
      :chef_popsicle => true,
      :ignored_parameters => ['Environment', 'StackCreator'],
      :chef_environment_parameter => 'Environment',
      :aws_commons => nil
    }

    attr_reader :stack, :stack_name, :stack_id, :options, :aws_commons

    def initialize(stack_name, options={})
      @stack_name = stack_name
      @options = DEFAULT_OPTIONS.merge(options)
      if(aws_commons?)
        @aws_commons = options[:aws_commons]
      else
        raise ArgumentError.new('Expecting `AwsCommons` instance but none provided!')
      end
      load_stack
    end

    def export
      exported = stack.to_hash
      if(chef_popsicle?)
        freeze_runlists(exported)
      end
      remove_ignored_parameters(exported)
      exported
    end

    def method_missing(*args)
      m = args.first.to_s
      if(m.end_with?('?') && options.has_key?(k = m.sub('?', '').to_sym))
        !!options[k]
      else
        super
      end
    end

    protected

    def remove_ignored_parameters(export)
      options[:ignored_parameters].each do |param|
        export[:parameters].delete(param)
      end
    end

    def chef_environment_name
      if(chef_environment_parameter?)
        name = stack[:parameters][options[:chef_environment_parameter]]
      end
      name || '_default'
    end

    def environment
      unless(@env)
        @env = Chef::Environment.load('_default')
      end
      @env
    end

    def load_stack
      @stack = AwsCommons::Stack.new(stack_name, aws_commons)
      @stack_id = @stack.stack_id
      @stack
    end

    def allowed_cookbook_version(cookbook)
      restriction = environment.cookbook_versions[cookbook]
      requirement = Gem::Requirement.new(restriction)
      Chef::CookbookVersion.available_versions(cookbook).detect do |v|
        requirement.satisfied_by?(Gem::Version.new(v))
      end
    end

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
        # dunno what this is
      end
      static_content
    end

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

    def freeze_runlists(exported)
      first_runs = locate_runlists(exported)
      first_runs.each do |first_run|
        unpack_and_freeze_runlist(first_run)
      end
    end

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

    def cf_ref(ref_name)
      if(stack.parameters.has_key?(ref_name))
        stack.parameters[ref_name]
      else
        raise KeyError.new("No parameter found with given reference name (#{ref_name}). " <<
          "Only parameter based references supported!")
      end
    end

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
