---
title: "Configuration"
weight: 2
anchors:
  - title: "sfn-based"
    url: "#sfn-based"
  - title: "knife-based"
    url: "#knife-based"
---


## Configuration

The configuration location of the `sfn` command is
dependent on the invocation method used. Since the
CLI application can be invoked as a standalone
application, or as a knife subcommand, two styles
of configuration are supported.

### `sfn`-based

Configuration is contained within a file named
`.sfn`.

Configuration for the `sfn` standalone application
utilizes the bogo-config library. This allows the
configuration file to be defined in multiple formats.
Supported formats:

* Ruby
* YAML
* JSON
* XML

#### JSON

~~~json
{
  "credentials": {
    "provider": "aws",
    "aws_access_key_id": "KEY_ID",
    "aws_access_secret_key": "SECRET_KEY",
    "aws_region": "REGION"
  },
  "options": {
    "disable_rollback": true
  }
}
~~~

#### YAML

~~~yaml
---
:credentials:
  :provider: "aws"
  :aws_access_key_id: "KEY_ID",
  :aws_access_secret_key: "SECRET_KEY",
  :aws_region: "REGION"
:options:
  :disable_rollback: true
~~~

#### XML

~~~xml
<configuration>
  <credentials>
    <provider>
      aws
    </provider>
    <aws_access_key_id>
      KEY_ID
    </aws_access_key_id>
    <aws_secret_access_key>
      SECRET_KEY
    </aws_secret_access_key>
    <aws_region>
      REGION
    </aws_region>
  </credentials>
  <options>
    <disable_rollback>
      true
    </disable_rollback>
  </options>
</configuration>
~~~

#### Ruby

~~~ruby
Configuration.new do
  credentials do
    provider "aws"
    aws_access_key_id "KEY_ID"
    aws_access_secret_key "SECRET_KEY"
    aws_region "REGION"
  end
  options.disable_rollback true
end
~~~

### Configuration Options

* `processing` - Enable SparkleFormation processing
  * Valid: Boolean
  * Default: `true`

* `apply_nesting` - Style of nested stack processing
  * Valid: `"shallow"`, `"deep"`
  * Default: `"deep"`

* `options` - API options for target orchestration API (passed through directly to target API)
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

* `credentials` - API credentials for target orchestration API (see [miasma](https://github.com/miasma-rb/miasma))
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
    * `template` - Callbacks to execute on template
      * Valid: `Array<String>`
      * Default: none
    * `default` - Callbacks to always execute
      * Valid: `Array<String>`
      * Default: none
    * `require` - List of custom libraries to load
      * Valid: `Array<String>`
      * Default: none

* `retry` - Configuration of API request retries
  * Valid: `Hash`
  * Default: none
    * `type` - Type of retry
      * Valid: `"flat"`, `"linear"`, `"exponential"`
      * Default: `"exponential"`
    * `interval` - Base wait interval for retry
      * Valid: `Numeric`
      * Default: 5
    * `max_attempts` - Maximum number of attempts allowed
      * Valid: `Numeric`
      * Default: 20
      * _NOTE_: Set to `nil` for infinite retry

* `stack_types` - Valid stack resource types
  * Valid: `Array<String>`
  * Default: `[DEFAULT_PROVIDER_TYPE]`

* `locations` - API credentials for named locations
  * Valid: `Hash`
  * Default: none

### `knife`-based

The `sfn` application includes a plugin for the
[knife][knife] CLI tool. Configuration can be
provided in the `.chef/knife.rb` file and commands
can be accessed via:


### Configuration

The easiest way to configure the plugin is via the
`.chef/knife.rb` file. All configuration options available
via the `.sfn` configuration file are allowed within the
`knife[:sparkleformation]` namespace:

#### AWS

```ruby
# .chef/knife.rb

knife[:sparkleformation][:credentials] = {
  :provider => :aws,
  :aws_access_key_id => ENV['AWS_ACCESS_KEY_ID'],
  :aws_secret_access_key => ENV['AWS_SECRET_ACCESS_KEY'],
  :aws_region => ENV['AWS_REGION']
}
knife[:sparkleformation][:options] = {:disable_rollback => true}
```

To view the available commands for the knife plugin:

~~~
$ knife sparkleformation --help
~~~

[knife]: https://docs.chef.io/knife.html
