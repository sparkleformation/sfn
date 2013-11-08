require 'knife-cloudformation/aws_commons'

module KnifeCloudformation
  class Export

    DEFAULT_OPTIONS = {
      :chef_popsicle => true
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
      exported
    end

    def method_missing(*args)
      m = args.first.to_s
      if(args.end_with?('?') && options.has_key?(k = m.sub('?', '').to_sym))
        !!options[k]
      else
        super
      end
    end

    protected

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
      if(rl_item.recipe?)
        cookbook, recipe = rl_item.name.split('::')
        peg_version = allowed_cookbook_version(cookbook)
        "recipe[#{[cookbook, recipe].join('::')}@#{beg_version}]"
      elsif(rl_item.role?)
        role = Chef::Role.load(rl_item.name)
        role.run_list.map do |item|
          item.run_list.map do |i|
            extract_runlist_item(i)
          end
        end
      else
        # dunno what this is
      end
    end

    def unpack_and_freeze_runlist(rl)
      new_hash = {'run_list' => []}
      new_rl = rl.map do |item|
        extract_runlist_item(cf_replace(item))
      end
      new_hash
    end

    def freeze_runlists(exported)
      first_runs = locate_runlists(exported)
      first_runs.each do |first_run|
        first_run.replace(
          'run_list' => unpack_and_freeze_runlist(first_run['run_list'])
        )
      end
    end

    def locate_runlists(thing)
      result = []
      case thing
      when Hash
        if(first_run = thing['content'] && first_run['run_list'])
          result << first_run
        else
          thing.each do |k,v|
            result += locate_runlists(v, ref)
          end
        end
      when Array
        thing.each do |v|
          result += locate_runlists(v, ref)
        end
      end
      result
    end

    def cf_replace(hsh)
      case hsh.keys.first
      when 'Fn::Join'
        cf_join(*hsh.values.first)
      when 'Ref'
        cf_ref(hsh.values.first)
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
          cf_replace(hsh)
        else
          arg.to_s
        end
      end.join(delim)
    end
  end
end
