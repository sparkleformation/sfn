---
title: "Lint"
weight: 8
anchors:
  - title: "Lint Framework"
    url: "#lint-framework"
  - title: "Composition"
    url: "#composition"
  - title: "Usage"
    url: "#usage"
---

## Lint

The lint framework built within the sfn tool utilizes the JMESPath query language
for identifying patterns and apply validation rules.

### Lint Framework

A rule set is a named collection of rules to be applied to a template. Each rule
is composed of one or more definitions. A rule passes only if _all_ definitions
can be successfully applied. Linting related classes:

* `Sfn::Lint::RuleSet`
* `Sfn::Lint::Rule`
* `Sfn::Lint::Definition`

### Composition

#### Long Form

##### `Sfn::Lint::Definition`

Definitions define a search expression to be applied to a given template. The search
expression is a JMESPath compatible query expression. The matches
of the search expression are then processed. If the results are valid, a `true` result
is expected. If the results are invalid, a `false` value is expected, or an `Array<String>`
value is expected which provides the list of invalid items.

~~~ruby
Sfn::Lint::Definition.new('Resources.[*][0][*].Type') do |matches, template|
  unless(search.nil?)
    result = search.find_all{|i| !i.start_with?('AWS')}
    result.empty? ? true : result
  else
    true
  end
end
~~~

The processing block is provided two arguments. The first is the match result of the
search expression. The second is the full template `Hash` that is being processed.

##### `Sfn::Lint::Rule`

Rules are composed of definitions. When a rule is applied to a template it will only
pass if _all_ definitions are successfully applied. A rule also includes a failure
message to provide user context of the failure.

~~~ruby
definition = Sfn::Lint::Definition.new('Resources.[*][0][*].Type') do |matches, template|
  unless(search.nil?)
    result = search.find_all{|i| !i.start_with?('AWS')}
    result.empty? ? true : result
  else
    true
  end
end

Sfn::Lint::Rule.new(
  :aws_resources_only,
  [definition],
  'All types must be within AWS root namespace'
)
~~~

##### `Sfn::Lint::RuleSet`

A rule set is a named collection of rules. It allows logically grouping related
rules together. Rule sets are the entry point of linting actions on templates. Once
a rule set has been created, it must then be registered to be made available.

~~~ruby
definition = Sfn::Lint::Definition.new('Resources.[*][0][*].Type') do |matches, template|
  unless(search.nil?)
    result = search.find_all{|i| !i.start_with?('AWS')}
    result.empty? ? true : result
  else
    true
  end
end

rule = Sfn::Lint::Rule.new(
  :aws_resources_only,
  [definition],
  'All types must be within AWS root namespace'
)

rule_set = Sfn::Lint::RuleSet.new(:aws_rules, [rule])
Sfn::Lint::RuleSet.register(rule_set)
~~~

#### Short Form

Rule sets can also be created using a generator which reduces the amount of effort required
for composition. The same rule set defined above can be created using the `RuleSet.build`
generator:

~~~ruby
rule_set = Sfn::Lint::RuleSet.build(:aws_rules) do
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

Sfn::Lint::RuleSet.register(rule_set)
~~~

### Usage

Linting functionality is available via the `lint` command. The only requirement of the `lint`
command is a template provided by the `--file` flag:

~~~
$ sfn lint --file my-template
~~~

By default all registered rule sets applicable to the template will be applied. Rule sets can
be disabled by name to prevent them from being applied:

~~~
$ sfn lint --file my-template --disable-rule-set aws_rules
~~~

or you can explicitly specify what rule sets should be applied:

~~~
$ sfn lint --file my-template --enable-rule-set aws_rules
~~~

#### Local rule sets

Rule sets can be created for a local project. These rule sets are kept within a directory, and
should be defined as a single rule set per file. For example, having a directory `tests/lint`
the rule set can be created:

~~~ruby
# tests/lint/resource_type_check.rb
RuleSet.build(:aws_rules) do
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

To include the local rule sets the target directory must be provided:

~~~
$ sfn lint --file my-template --lint-directory tests/lint
~~~

and if _only_ local rule sets should be applied, it is possible to disable all registered
rule sets:

~~~
$ sfn lint --file my-template --lint-directory tests/lint --local-rule-sets-only
~~~
