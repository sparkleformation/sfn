---
title: "Configuration"
weight: 2
anchors:
  - title: "sfn-based"
    url: "#sfn-based"
  - title: "knife-based"
    url: "#knife-based"
  - title: "configuration-options"
    url: "#configuration-options"
---


## Configuration

The configuration location of the `sfn` command is
dependent on the invocation method used. Since the
CLI application can be invoked as a standalone
application, or as a knife subcommand, two styles
of configuration are supported.

### `sfn`-based

Configuration for the `sfn` standalone application
utilizes the bogo-config library. This allows the
configuration file to be defined in multiple formats.
Supported formats:

* Ruby
* YAML
* JSON
* XML

The configuration is contained within a file named
`.sfn`.

### `knife`-based

The `sfn` application includes a plugin for the
[knife][knife] CLI tool. Configuration can be
provided in the `.chef/knife.rb` file and commands
can be accessed via:

~~~
$ knife sparkleformation --help
~~~

### Configuration Options

| Option                     | Attribute     | Value
|----------------------------|---------------|---------------------------------------------------------------
| `processing`               | Description   | Enable SparkleFormation processing
|                            | Valid         | `TrueClass`, `FalseClass`
|                            | Default       | `true`
|----------------------------|---------------|---------------------------------------------------------------
| `apply_nesting`            | Description   | Style of nested stack processing
|                            | Valid         | `"shallow"`, `"deep"`
|                            | Default       | `"deep"`
|----------------------------|---------------|---------------------------------------------------------------
| `options`                  | Description   | API options for target API (see miasma)
|                            | Valid         | `Hash`
|                            | Default       | none
|----------------------------|---------------|---------------------------------------------------------------
| `ssh_attempt_users`        | Description   | List of users to attempt SSH connection on node failure
|                            | Valid         | `Array<String>`
|                            | Default       | none
|----------------------------|---------------|---------------------------------------------------------------
| `identity_file`            | Description   | Custom SSH identity file for node failure connection
|                            | Valid         | `String`
|                            | Default       | none
|----------------------------|---------------|---------------------------------------------------------------
| `nesting_bucket`           | Description   | Name of bucket to store nested stack templates
|                            | Valid         | `String`
|                            | Default       | none
|----------------------------|---------------|---------------------------------------------------------------
| `nesting_prefix`           | Description   | Prefix to prepend to template file name within object store
|                            | Valid         | `String`
|                            | Default       | none
|----------------------------|---------------|---------------------------------------------------------------
| `sparkle_pack`             | Description   | SparklePacks to load
|                            | Valid         | `Array<String>`
|                            | Default       | none
|----------------------------|---------------|---------------------------------------------------------------
| `parameters`               | Description   | Stack runtime parameters
|                            | Valid         | `Hash`
|                            | Default       | none
|----------------------------|---------------|---------------------------------------------------------------
| `credentials`              | Description   | API credentials for target orchestration API
|                            | Valid         | `Hash`
|                            | Default       | none
|----------------------------|---------------|---------------------------------------------------------------
| `callbacks`                | Description   | Callbacks to execute around API calls
|                            | Valid         | `Hash`
|                            | Default       | none
|----------------------------|---------------|---------------------------------------------------------------
| `callbacks.before`         | Description   | Callbacks to execute before _any_ API call
|                            | Valid         | `Array<String>`
|                            | Default       | none
|----------------------------|---------------|---------------------------------------------------------------
| `callbacks.after`          | Description   | Callbacks to execute after _any_ API call
|                            | Valid         | `Array<String>`
|                            | Default       | none
|----------------------------|---------------|---------------------------------------------------------------
| `callbacks.before_COMMAND` | Description   | Callbacks to execute before specific `COMMAND` API call
|                            | Valid         | `Array<String>`
|                            | Default       | none
|----------------------------|---------------|---------------------------------------------------------------
| `callbacks.after_COMMAND`  | Description   | Callbacks to execute after specific `COMMAND` API call
|                            | Valid         | `Array<String>`
|                            | Default       | none
|----------------------------|---------------|---------------------------------------------------------------
| `callbacks.template`       | Description   | Callbacks to execute on template
|                            | Valid         | `Array<String>`
|                            | Default       | none
|----------------------------|---------------|---------------------------------------------------------------
| `callbacks.default`        | Description   | Callbacks to always execute
|                            | Valid         | `Array<String>`
|                            | Default       | none
|----------------------------|---------------|---------------------------------------------------------------
| `callbacks.require`        | Description   | List of custom libraries to load
|                            | Valid         | `Array<String>`
|                            | Default       | none
|----------------------------|---------------|---------------------------------------------------------------
| `retries`                  | Description   | Configuration of API request retries
|                            | Valid         | `Hash`
|                            | Default       | none
|----------------------------|---------------|---------------------------------------------------------------
| `retries.type`             | Description   | Retry implementation
|                            | Valid         | `"flat"`, `"linear"`, `"exponential"`
|                            | Default       | `"exponential"`
|----------------------------|---------------|---------------------------------------------------------------
| `retries.interval`         | Description   | Base wait interval for retry
|                            | Valid         | `Numeric`
|                            | Default       | `5`
|----------------------------|---------------|---------------------------------------------------------------
| `retries.max_attempts`     | Description   | Maximum number of attempts allowed (`nil` for infinite retry)
|                            | Valid         | `Numeric`, `NilClass`
|                            | Default       | `20`
|----------------------------|---------------|---------------------------------------------------------------
| `stack_types`              | Description   | Define customized stack resource types
|                            | Valid         | `Array<String>`
|                            | Default       | `[DEFAULT_PROVIDER_TYPE]`
|----------------------------|---------------|---------------------------------------------------------------
| `locations`                | Description   | API credentials for named locations (JackalStack resources)
|                            | Valid         | `Hash`
|                            | Default       | none
|----------------------------|---------------|---------------------------------------------------------------

[knife]: https://docs.chef.io/knife.html
