---
title: "Usage"
weight: 3
anchors:
  - title: "Directory Structure"
    url: "#directory-structure"
  - title: "Template Commands"
    url: "#template-commands"
  - title: "Stack Commands"
    url: "#stack-commands"
---

## Usage

The `sfn` command can be invoked in two ways. The
first is directly:

~~~
$ sfn --help
~~~

The second is via the [knife][knife] plugin:

~~~
$ knife sparkleformation --help
~~~

Both invocations will generate the same result. The
direct `sfn` command can be preferable as it does not
require loading outside libraries nor does it traverse
the filesystem loading plugins. Because of this, the
direct command will generally be faster than the knife
plugin.

### Directory Structure

The `sfn` command utilizes the [SparkleFormation][sparkle_formation]
library and supports template compilation. To use SparkleFormation,
just create the directory structure within the local project
working directory:

~~~
> tree
.
|____sparkleformation
| |____dynamics
| |____components
| |____registry
~~~

### Commands

#### Template Commands

These are the commands that support an orchestration template.
By default, `sfn` does not enable the [SparkleFormation][sparkle_formation]
integration. This means that any innvocation when a template is
required _must_ provide a path to the serialized document using
the `--file` option.

To enable the [SparkleFormation][sparkle_formation] integration
simply include the `---processing` flag, or enable it via the
configuration file:

~~~ruby
Configuration.new do
  processing true
end
~~~

When processing is enabled and no path is provided via the `--file`
option, `sfn` will prompt for template selection allowing the user
to choose from local templates, as well as any templates distributed
in loaded [SparklePacks][sparkle_packs].

Available template related commands:

* `sfn create`
* `sfn update`
* `sfn validate`

The `sfn` command supports the advanced nesting functionality provided
by the [SparkleFormation][sparkle_formation] library. There are two
styles of nesting functionality available: shallow and deep. The required
style can be set via the configuration file:

~~~ruby
Configuration.new do
  apply_nesting 'deep'
end
~~~

The default nesting functionality is `"deep"`. To learn more about
the nesting functionality please refer to the [SparkleFormation nested
stacks][nested_stacks] documentation.

When using nested stacks, a bucket is required for storage of the
nested stack templates. `sfn` will automatically store nested templates
into the defined bucket, but the bucket name _must_ be provided and
the bucket _must_ exist. The bucket name can be defined within the
configuration:

~~~ruby
Configuration.new do
  nesting_bucket 'my-nested-templates'
end
~~~

#### Stack Commands

These commands are used for inspection or removal of existing stacks:

* `sfn describe`
* `sfn inspect`
* `sfn events`
* `sfn destroy`

While the `describe` command is good for an overview of a stack contents
(resources and outputs), the `inspect` command allows for deeper inspection
of a given stack. The `--attribute` option allows access to the underlying
data model that represents the given resource and can be inspected for
information. The data modeling is provided by the [miasma][miasma] cloud
library which can be referenced for supported methods available. As an
example, given an AWS CloudFormation stack with a single EC2 resource,
the `inspect` command can be used to provide all addresses associated
with the instance:

~~~
$ sfn inspect my-stack --attribute 'resources.all.at(0).expand.addresses'
~~~

[knife]: https://docs.chef.io/knife.html
[sparkle_formation]: /docs/sparkle_formation/README.html
[sparkle_packs]: /docs/sparkle_formation/sparkle-packs.html
[miasma]: https://github.com/miasma-rb/miasma
