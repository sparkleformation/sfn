# Knife CloudFormation

This is a plugin for the `knife` command provided by
Chef to interact with AWS (and other) orchestration
APIs.

## API Compatibility

* AWS
* Rackspace
* OpenStack

## Configuration

The easiest way to configure the plugin is via the
`knife.rb` file. Credentials are the only configuration
requirement, and the `Hash` provided is proxied to
Miasma:

### AWS

```ruby
# .chef/knife.rb

knife[:cloudformation][:credentials] = {
  :provider => :aws,
  :aws_access_key_id => ENV['AWS_ACCESS_KEY_ID'],
  :aws_secret_access_key => ENV['AWS_SECRET_ACCESS_KEY'],
  :aws_region => ENV['AWS_REGION']
}
```

### Rackspace

```ruby
# .chef/knife.rb

knife[:cloudformation][:credentials] = {
  :provider => :rackspace,
  :rackspace_username => ENV['RACKSPACE_USERNAME'],
  :rackspace_api_key => ENV['RACKSPACE_API_KEY'],
  :rackspace_region => ENV['RACKSPACE_REGION']
}
```

### OpenStack

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

## Commands

* `knife cloudformation list`
* `knife cloudformation create`
* `knife cloudformation update`
* `knife cloudformation destroy`
* `knife cloudformation events`
* `knife cloudformation describe`
* `knife cloudformation inspect`
* `knife cloudformation validate`

### `knife cloudformation list`

Provides listing of current stacks and state of each stack.

#### Supported options

* `--attribute ATTR` stack attribute to display
* `--status STATUS` match stacks with given status

### `knife cloudformation validate`

Validates template with API

#### Supported options

* `--[no-]processing` enable template processing
* `--file PATH` path to stack template file
* `--translate PROVIDER` translate template to provider
* `--[no-]apply-nesting` apply template nesting logic
* `--nesting-bucket BUCKET` asset store bucket to place nested stack templates

### `knife cloudformation create NAME`

Creates a new stack with the provided name (`NAME`).

#### Supported options

* `--timeout MINUTES` stack creation timeout limit
* `--[no-]rollback` disable rollback on failure
* `--capability CAPABILITY` enable capability within API
* `--notifications ARN` add notification ARN
* `--print-only` print stack template JSON and exit
* `--apply-stacks NAME` apply existing stack outputs
* `--[no-]processing` enable template processing
* `--file PATH` path to stack template file
* `--translate PROVIDER` translate template to provider
* `--[no-]apply-nesting` apply template nesting logic
* `--nesting-bucket BUCKET` asset store bucket to place nested stack templates

#### Apply Stacks

The `--apply-stacks` option allows providing the name of an existing
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

When creating StackB, if we use the `--apply-stacks` option:

```
$ knife cloudformation create StackB --apply-stacks StackA
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

### `knife cloudformation update STACK`

Update an existing stack.

#### Supported options

* `--print-only` print stack template JSON and exit
* `--apply-stacks NAME` apply existing stack outputs
* `--[no-]processing` enable template processing
* `--file PATH` path to stack template file
* `--translate PROVIDER` translate template to provider
* `--[no-]apply-nesting` apply template nesting logic
* `--nesting-bucket BUCKET` asset store bucket to place nested stack templates

### `knife cloudformation destroy STACK`

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
$ knife cloudformation destroy Test*
```

will destroy the `TestStack1` and `TestStack2`

### `knife cloudformation events STACK`

Display the event listing of given stack. If the state of the
stack is "in progress", the polling option will result in
polling and displaying new events until the stack reaches a
completed state.

#### Supported options

* `--[no-]poll` poll for new events until completed state reached

### `knife cloudformation describe STACK`

Display resources and outputs of give stack.

#### Supported options

* `--resources` display resources
* `--outputs` display outputs

### `knife cloudformation inspect STACK`

The stack inspection command simply provides a proxy to the
underlying resource modeling objects provided via the
(miasma)[https://github.com/miasma-rb/miasma] library. It
also provides extra helpers for running common inspection
commands.

### Supported options

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
miasma resource modeling. The value of `ATTR` is what should be
called on the `Miasma::Models::Orchestration::Stack` instance.
For example, to display the JSON template of a stack:

```
$ knife cloudformation inspect STACK -a template
```

To display the resource collection of the stack:

```
$ knife cloudformation inspect STACK -a resources
```

This will provide a list of resources. Now, to make this more
useful, we can start inspect specific resources. Lets assume
that the 3rd resource in the collection is an auto scaling
group resource. We can isolate that resource for display:

```
$ knife cloudformation inspect STACK -a "resources.all.at(2)"
```

Note that the resources are an array, and we are using a zero
based index. Now, this simply provides us with the information
we already have seen. One of the handy features within the
miasma library is the ability to expand supported resources.
So, we can expand this resource:

```
$ knife cloudformation inspect STACK -a "resources.all.at(2).expand"
```

This will expand the resource instance and return the actual
auto scaling group resource. The result will provide more detailed
information about the scaling group. But, perhaps we are looking
for the instances in this scaling group. The model instance we
now have (`Miasma::Orchestration::Models::AutoScale::Group`)
contains a `servers` attribute. The output lists the IDs of the
instances, but we can expand those as well:

```
$ knife cloudformation inspect STACK -a "resources.all.at(2).expand.servers.map(&:expand)"
```

The attribute string will be minimally processed when proxying calls
to the underlying models, which is why we are able to do ruby-ish
style things.

# Info

* Repository: https://github.com/hw-labs/knife-cloudformation
* IRC: Freenode @ #heavywater