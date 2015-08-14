# SparkleFormation CLI

SparkleFormation command line interface for interacting
with orchestration APIs.

## API Compatibility

* AWS
* Rackspace
* OpenStack

## Configuration

Configuration is defined within a `.sfn` file. The
`sfn` command will start from the current working
directory and work up to the root of the file system
to discover this file.

### Configuration formats

The configuration file can be provided in a variety of
formats:

#### JSON

```json
{
  "credentials": {
    AWS_CREDENTIALS
  },
  "options": {
    "disable_rollback": true
  }
}
```

#### YAML

```yaml
---
:credentials:
  :fubar: true
:options:
  :disable_rollback: true
```

#### XML

```xml
<configuration>
  <credentials>
    AWS_CREDENTIALS
  </credentials>
  <options>
    <disable_rollback>
      true
    </disable_rollback>
  </options>
</configuration>
```

#### Ruby

```ruby
Configuration.new do
  credentials do
    AWS_CREDENTIALS
  end
  options.on_failure 'nothing'
end
```

### Configuration Options

* `processing` - Enable SparkleFormation processing
  * Valid: Boolean
  * Default: `true`

* `apply_nesting` - Style of nested stack processing
  * Valid: `"shallow"`, `"deep"`
  * Default: `"deep"`

* `options` - API options for target orchestration API (see miasma)
  * Valid: `Hash`
  * Default: none

* `ssh_attempt_users` - List of users to attempt SSH connection on node failure
  * Valid: `Array<String>`
  * Default: none

* `identity_file` - Custom SSH identity file to use for connection on node failure
  * Valid: `String`
  * Default: none

* `nesting_bucket` - Name of bucket to store nested stack templates
  * Valid: `String`
  * Default: none

* `credentials` - API credentials for target orchestration API (see miasma)
  * Valid: `Hash`
  * Default: none

* `callbacks` - Callbacks to execute around API calls
  * Valid: `Hash`
  * Default: none
    * `before` - Callbacks to execute before _any_ API call
      * Valid: `Array<String>`
      * Default: none
    * `after` - Callbacks to execute after _any_ API call
      * Valid: `Array<String>`
      * Default: none
    * `before_COMMAND` - Callbacks to execute before specific `COMMAND` API call
      * Valid: `Array<String>`
      * Default: none
    * `after_COMMAND` - Callbacks to execute after specific `COMMAND` API call
      * Valid: `Array<String>`
      * Default: none

## Commands

* `sfn list`
* `sfn create`
* `sfn update`
* `sfn destroy`
* `sfn events`
* `sfn describe`
* `sfn inspect`
* `sfn validate`

_NOTE: All commands respond to `--help` and will provide a full list of valid options._

### `sfn list`

Provides listing of current stacks and state of each stack.

### `sfn validate`

Validates template with API

### `sfn create NAME`

Creates a new stack with the provided name (`NAME`).

#### Apply Stacks

The `--apply-stack` option allows providing the name of an existing
stack when creating or updating. Applying stacks is simply fetching
the outputs from the applied stacks and automatically defaulting the
set parameter of the new or updated stack. Outputs are matched
by name to the parameters of the target stack. This allows an easy
way to use values from existing stacks when building new stacks.

Example:

StackA:

```json
...
  "Outputs": {
    "LoadBalancerAddress": {
      "Description": "Address of Load Balancer",
      "Value": {
        "Fn::GetAtt": [
          "LoadBalancerResource",
          "DNSName"
        ]
      }
    }
  }
...
```

StackB:

```json
...
  "Parameters": {
    "LoadBalancerAddress": {
      "Type": "String",
      "Default": "unset"
    }
  }
...
```

When creating StackB, if we use the `--apply-stack` option:

```
$ sfn create StackB --apply-stack StackA
```

when prompted for the stack parameters, we will find the parameter
value for `LoadBalancerAddress` to be filled in with the output
provided from StackA.

#### Processing

The default behavior of this plugin assumes templates will be
in JSON format. The `--processing` flag will allow providing Ruby
files to dynamically generate templates using the SparkleFormation
library.

_NOTE: (SparkleFormation Usage Documentation)[]._

This plugin supports the advanced stack nesting feature provided by
the SparkleFormation library.

#### Translations

Translations are currently an `alpha` feature and only a subset of
resources are supported.

### `sfn update STACK`

Update an existing stack.

### `sfn destroy STACK`

Destroy an existing stack.

#### Name globs

The destroy command supports globbing for performing multiple
destructions based on glob match. For example, given existing
stacks:

* TestStack1
* TestStack2
* Production

running the following command:

```
$ sfn destroy Test*
```

will destroy the `TestStack1` and `TestStack2`

### `sfn events STACK`

Display the event listing of given stack. If the state of the
stack is "in progress", the polling option will result in
polling and displaying new events until the stack reaches a
completed state.

### `sfn describe STACK`

Display resources and outputs of give stack.


### `sfn inspect STACK`

The stack inspection command simply provides a proxy to the
underlying resource modeling objects provided via the
[miasma][miasma] library. It also provides extra helpers for
running common inspection commands.

### Interesting `inspect` options

* `--nodes` list node addresses within stack
* `--instance-failure [LOG_FILE]` print log file from failed instance
* `--attribute ATTR` print stack attribute

#### `--nodes`

This option will return a list of compute instance IDs and
their addresses. The result will be a complete list including
direct compute resources within the stack as well as compute
resources that are part of auto scaling group resouces.

#### `--instance-failure [LOG_FILE]`

If the stack create or update failed due to a compute instance,
this option will attempt to locate the instance, connect to
it and download the defined log file. The default log file
is set to: `/var/log/chef/client.log`

#### `--attribute ATTR`

The attribute option is what provides the proxy to the underlying
[miasma][miasma] resource modeling. The value of `ATTR` is what should be
called on the `Miasma::Models::Orchestration::Stack` instance.
For example, to display the JSON template of a stack:

```
$ sfn inspect STACK -a template
```

To display the resource collection of the stack:

```
$ sfn inspect STACK -a resources
```

This will provide a list of resources. Now, to make this more
useful, we can start inspect specific resources. Lets assume
that the 3rd resource in the collection is an auto scaling
group resource. We can isolate that resource for display:

```
$ sfn inspect STACK -a "resources.all.at(2)"
```

Note that the resources are an array, and we are using a zero
based index. Now, this simply provides us with the information
we already have seen. One of the handy features within the
[miasma][miasma] library is the ability to expand supported resources.
So, we can expand this resource:

```
$ sfn inspect STACK -a "resources.all.at(2).expand"
```

This will expand the resource instance and return the actual
auto scaling group resource. The result will provide more detailed
information about the scaling group. But, perhaps we are looking
for the instances in this scaling group. The model instance we
now have (`Miasma::Orchestration::Models::AutoScale::Group`)
contains a `servers` attribute. The output lists the IDs of the
instances, but we can expand those as well:

```
$ sfn inspect STACK -a "resources.all.at(2).expand.servers.map(&:expand)"
```

The attribute string will be minimally processed when proxying calls
to the underlying models, which is why we are able to do ruby-ish
style things.

## Chef Knife Integration

This library will also provide `cloudformation` subcommands
to knife.

### Configuration

The easiest way to configure the plugin is via the
`knife.rb` file. Credentials are the only configuration
requirement, and the `Hash` provided is proxied to
[Miasma][miasma]. All configuration options provided
via the `sfn` command are allowed within the
`knife[:cloudformation]` namespace:

#### AWS

```ruby
# .chef/knife.rb

knife[:cloudformation][:credentials] = {
  :provider => :aws,
  :aws_access_key_id => ENV['AWS_ACCESS_KEY_ID'],
  :aws_secret_access_key => ENV['AWS_SECRET_ACCESS_KEY'],
  :aws_region => ENV['AWS_REGION']
}
```

#### Rackspace

```ruby
# .chef/knife.rb

knife[:cloudformation][:credentials] = {
  :provider => :rackspace,
  :rackspace_username => ENV['RACKSPACE_USERNAME'],
  :rackspace_api_key => ENV['RACKSPACE_API_KEY'],
  :rackspace_region => ENV['RACKSPACE_REGION']
}
```

#### OpenStack

```ruby
# .chef/knife.rb

knife[:cloudformation][:credentials] = {
  :provider => :open_stack,
  :open_stack_username => ENV['OPENSTACK_USERNAME'],
  :open_stack_password => ENV['OPENSTACK_PASSWORD'],
  :open_stack_identity_url => ENV['OPENSTACK_IDENTITY_URL'],
  :open_stack_tenant_name => ENV['OPENSTACK_TENANT']
}
```

### Usage

All commands available via the `sfn` command are available as
knife subcommands under `cloudformation` and `sparkleformation`

```
$ knife cloudformation --help
```

or

```
$ knife sparkleformation --help
```

# Info

* Repository: https://github.com/sparkleformation/sfn
* IRC: Freenode @ #sparkleformation

[miasma]: http://miasma-rb.github.io/miasma/