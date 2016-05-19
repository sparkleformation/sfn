---
title: "Lint"
weight: 5
---

## Lint

_NOTE: Lint support is currently local definitions only._

### Usage

Provide a template and lint directory to the `lint` command. For example,
if lint rule sets are defined within `tests/lint`:

~~~
$ sfn lint --file my-template --lint-directory tests/lint
~~~

### Lint RuleSets

Create rule sets using the generator. Each file must contain a single
lint rule set. Below is a simple rule set used to flag non-AWS type
resources:

~~~ruby
# tests/lint/resource_type_check.rb

RuleSet.build(:test) do
  rule :aws_resources_only do
    definition 'Resources.[*][0][*].Type' do |search|
      unless(search.nil?)
        result = search.find_all{|i| !i.start_with?('AWS')}
        result.empty? ? true : result
      else
        true
      end
    end

    fail_message 'All types must be within AWS root namespace'
  end
end
~~~
