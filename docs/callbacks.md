---
title: "Callbacks"
weight: 4
anchors:
  - title: "Enabling Callbacks"
    url: "#enabling-callbacks"
  - title: "Builtin Callbacks"
    url: "#builtin-callbacks"
  - title: "Custom Callbacks"
    url: "#custom-callbacks"
  - title: "Addon Callbacks"
    url: "#addon-callbacks"
---

## Callbacks

Callbacks provide a way to inject optional functionality
or custom functionality into `sfn` commands. Callbacks
are generally invoked in two places:

* `before` - Prior to the command's remote API request
* `after` - Following the command's remote API request

There are also callbacks available prior to the execution
of a command. These can also be isolated to specific commands:

* `after_config` - Prior to the execution of the command.

### Enabling Callbacks

Callbacks can be applied globally (to all commands) or
to specific commands. For example, applying a before callback
to _all_ commands:

~~~ruby
Configuration.new do
  callbacks.before ['custom_callback']
end
~~~

Applying a before callback to only the `create` command:

~~~ruby
Configuration.new do
  callbacks.before_create ['custom_callback']
end
~~~

The other place a callback can be invoked is after a
template has been loaded. This can allow the callback
to perform some action on the loaded template prior to
the command being executed. Enabling a template callback:

~~~ruby
Configuration.new do
  callbacks.template ['my-custom-callback']
end
~~~

When a stack does not include nested stacks, a `before`
callback can be sufficient for allowing modificiations
to a template prior to the command being executed. However,
when a stack contains nested stacks, those templates will
be processed and stored prior to the invocation of any
registered `before` callbacks. For this reason, it is
best to use the `template` callback when registering callbacks
that modify a template contents.

Finally, because callbacks can be distributed via gem it
may be required to load the libraries so the callback is
accessible:

~~~ruby
Configuration.new do
  callbacks.require ['my-custom-callback']
end
~~~

### Builtin Callbacks

Builtin callbacks distributed with `sfn`:

* AWS Assume Role
* AWS MFA
* Stack Policy

#### AWS Assume Role

When assuming a role via STS on AWS a temporary set of credentials and token
are generated for use. This callback will cache these credentials for re-use
to prevent re-generation of temporary credentials on every command request.

To enable the callback:

~~~ruby
Configuration.new do
  callbacks do
    default ['aws_assume_role']
  end
end
~~~

Once temporary credentials have been generated, the callback will store the credentials
within a file in the working directory named `.sfn-aws`. This path can be modified via
configuration:

~~~ruby
Configuration.new do
  aws_assume_role do
    cache_file '/custom/path/to/file'
  end
end
~~~

Loading and storage of credentials will only occur if a role is provided to assume. Given
a configuration of:

~~~ruby
Configuration.new do
  callbacks.default 'aws_assume_role'
  credentials do
    aws_sts_role_arn ENV['AWS_STS_ROLE']
  end
end
~~~

The callback will be enabled when the environment variable is provided:

~~~
$ AWS_STS_ROLE="arn:...MY_ROLE" sfn list
~~~

and will not be enabled when the environment variable is not provided:

~~~
$ sfn list
~~~

It can also be disabled/enabled via configuration setting:

~~~ruby
Configuration.new do
  aws_assume_role.status 'enabled'
end
~~~

#### AWS Multifactor Authentication

Support for MFA within AWS can be provided using the AWS MFA callback. It will
prompt for an MFA token code which is then used to generate the new session.

To enable the callback:

~~~ruby
Configuration.new do
  callbacks do
    default ['aws_mfa']
  end
end
~~~

The default virtual MFA device ARN will be used when creating the new session. If a
non-default virutal MFA device or a hardware device is being used, set the device
serial number with the configuration:

~~~ruby
Configuration.new do
  credentials do
    provider :aws
    aws_sts_mfa_serial_number 'DEVICE_IDENTIFIER'
  end
end
~~~

After a session has been successfully created, the callback will store the session
token and credentials within a file in the working directory named `.sfn-aws`. This
path can be configured via configuration:

~~~ruby
Configuration.new do
  aws_mfa do
    cache_file '/custom/path/to/file'
  end
end
~~~

Use of MFA may be conditional based on actions performed. For easier toggling of
MFA usage, a configuration value can be used to enable or disable MFA:

~~~ruby
Configuration.new do
  aws_mfa do
    cache_file ENV.fetch('SFN_MFA', 'enabled')
  end
end
~~~

With this configuration, MFA usage can be easily disabled:

~~~
$ SFN_MFA=disabled sfn list
~~~

#### Stack Policy Callback

The Stack Policy Callback utilizes the [policy feature](http://www.sparkleformation.io/docs/sparkle_formation/stack-policies.html)
built into the [SparkleFormation](http://www.sparkleformation.io/docs/sparkle_formation)
library.

To enable the callback:

~~~ruby
Configuration.new do
  callbacks do
    default ['stack_policy']
  end
end
~~~

By default a stack policy is not disabled when an update command is run. This may
require multiple update commands to be run first disabling the existing policy, then
running the actual update. Stack policies can be automatically removed prior to update
allowing the stack to be properly updated with the newly generated policy applied on
completion. To disable the stack policy on update, add this to your configuration:

~~~ruby
Configuration.new do
  stack_policy.update 'defenseless'
end
~~~

### Custom Callbacks

To create a custom callback define a new class within the callback namespace
and subclass the abstract class:

~~~ruby
module Sfn
  class Callback
    class MyCallback < Callback
    end
  end
end
~~~

Providing a method that matches the callback name requested will enable
its functionality. For example, running an action after every command:

~~~ruby
module Sfn
  class Callback
    class MyCallback < Callback

      def after(args)
        # do things
      end

    end
  end
end
~~~

or after the `create` command:

~~~ruby
module Sfn
  class Callback
    class MyCallback < Callback

      def after_create(args)
        # do things
      end

    end
  end
end
~~~

The `args` referenced above will be a `Hash` composed of some or all of
the following:

* `:api_stack` - The `Miasma::Models::Orchestration::Stack` instance of the remote stack
* `:stack_name` - Name of the stack
* `:sparkle_stack` - The `SparkleFormation` instance of the template
* `:hash_stack` - The `Hash` instance of the template

Enabling the custom callback is the same as above:

~~~ruby
Configuration.new do
  callbacks.after ['custom_callback']
end
~~~

The sfn command will output a notification to the user before a callback is
run, and after it has completed. This may be too verbose for some callbacks.
A callback may disable this output using the `quiet` method:

```ruby
module Sfn
  class Callback
    class MyCallback < Callback

      def quiet
        true
      end

    end
  end
end
```

### Addon Callbacks

#### Usage

Addon callbacks must be installed to the local bundle, or the system depending
on usage type.

For bundle usage, add the callback to the Gemfile:

~~~ruby
gem 'sfn-callback-name'
~~~

For system usage, install the gem:

~~~
$ gem install sfn-callback-name
~~~

#### Callbacks

##### sfn-parameters

Manage stack parameters via files within the project repository.

* https://github.com/sparkleformation/sfn-parameters

##### sfn-serverspec

Define Serverspec rules directly on resources within templates
and automatically run after success stack creation or update.

* https://github.com/sparkleformation/sfn-serverspec