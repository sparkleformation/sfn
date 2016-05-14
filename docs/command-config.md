---
title: "Commands and configuration"
weight: 3
anchors:
  - title: "Conf Command"
    url: "#conf-command"
  - title: "Create Command"
    url: "#create-command"
  - title: "Describe Command"
    url: "#describe-command"
  - title: "Destroy Command"
    url: "#destroy-command"
  - title: "Diff Command"
    url: "#diff-command"
  - title: "Events Command"
    url: "#events-command"
  - title: "Export Command"
    url: "#export-command"
  - title: "Graph Command"
    url: "#graph-command"
  - title: "Import Command"
    url: "#import-command"
  - title: "Init Command"
    url: "#init-command"
  - title: "Inspect Command"
    url: "#inspect-command"
  - title: "List Command"
    url: "#list-command"
  - title: "Print Command"
    url: "#print-command"
  - title: "Promote Command"
    url: "#promote-command"
  - title: "Update Command"
    url: "#update-command"
  - title: "Validate Command"
    url: "#validate-command"
---
## Conf Command

~~~
$ sfn conf
~~~

| Option | Attribute | Value
|--------|-----------|------
| `--apply-mapping` | Description | Customize apply stack mapping as [StackName__]OutputName:ParameterName (Key:Value[,Key:Value,...]) |
| | Valid | `Bogo::Smash` |
| | Default | |
| `--apply-nesting` | Description | Apply stack nesting |
| | Valid | `String`, `Symbol` |
| | Default | "deep"|
| `--apply-stack` | Description | Apply outputs from stack to input parameters |
| | Valid | `String` |
| | Default | |
| `--base-directory` | Description | Path to root of of templates directory |
| | Valid | `String` |
| | Default | |
| `--compile-parameters` | Description | Pass template compile time parameters directly |
| | Valid | `Bogo::Smash` |
| | Default | |
| `--config` | Description | Configuration file path |
| | Valid | `String` |
| | Default | |
| `--credentials` | Description | Provider credentials (Key:Value[,Key:Value,...]) |
| | Valid | `Bogo::Smash` |
| | Default | |
| `--debug` | Description | Enable debug output |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | |
| `--defaults` | Description | Automatically accept default values |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | |
| `--diffs` | Description | Show planner content diff |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | |
| `--file` | Description | Path to template file |
| | Valid | `String` |
| | Default | |
| `--file-path-prompt` | Description | Enable interactive prompt for template path discovery |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | true|
| `--generate` | Description | Generate a basic configuration file |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | |
| `--ignore-parameters` | Description | Parameters to ignore during modifications |
| | Valid | `String` |
| | Default | |
| `--interactive-parameters` | Description | Prompt for template parameters |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | true|
| `--merge-api-options` | Description | Merge API options defined within configuration on update |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | false|
| `--nesting-bucket` | Description | Bucket to use for storing nested stack templates |
| | Valid | `String` |
| | Default | |
| `--nesting-prefix` | Description | File name prefix for storing template in bucket |
| | Valid | `String` |
| | Default | |
| `--no-base-directory` | Description | Unset any value used for the template root directory path |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | |
| `--notification-topics` | Description | Notification endpoints for stack events |
| | Valid | `String` |
| | Default | |
| `--options` | Description | Extra options to apply to the API call (Key:Value[,Key:Value,...]) |
| | Valid | `Bogo::Smash` |
| | Default | |
| `--parameter` | Description | [DEPRECATED - use `parameters`] Pass template parameters directly (ParamName:ParamValue) |
| | Valid | `Bogo::Smash` |
| | Default | |
| `--parameter-validation` | Description | Stack parameter validation behavior |
| | Valid | `String` |
| | Default | "default"|
| `--parameters` | Description | Pass template parameters directly (Key:Value[,Key:Value,...]) |
| | Valid | `Bogo::Smash` |
| | Default | |
| `--plan` | Description | Provide planning information prior to update |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | true|
| `--plan-only` | Description | Exit after plan display |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | false|
| `--poll` | Description | Poll stack events on modification actions |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | true|
| `--print-only` | Description | Print the resulting stack template |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | |
| `--processing` | Description | Call the unicorns and explode the glitter bombs |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | true|
| `--rollback` | Description | Rollback stack on failure |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | |
| `--sparkle-pack` | Description | Load SparklePack gem |
| | Valid | `String` |
| | Default | |
| `--timeout` | Description | Seconds to wait for stack to complete |
| | Valid | `Integer` |
| | Default | |
| `--translate` | Description | Translate generated template to given provider |
| | Valid | `String` |
| | Default | |
| `--translate-chunk` | Description | Chunk length for serialization |
| | Valid | `Integer` |
| | Default | |
| `--upload-root-template` | Description | Upload root template to storage bucket |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | |
| `--yes` | Description | Automatically accept any requests for confirmation |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | |

## Create Command

~~~
$ sfn create
~~~

| Option | Attribute | Value
|--------|-----------|------
| `--apply-mapping` | Description | Customize apply stack mapping as [StackName__]OutputName:ParameterName (Key:Value[,Key:Value,...]) |
| | Valid | `Bogo::Smash` |
| | Default | |
| `--apply-nesting` | Description | Apply stack nesting |
| | Valid | `String`, `Symbol` |
| | Default | "deep"|
| `--apply-stack` | Description | Apply outputs from stack to input parameters |
| | Valid | `String` |
| | Default | |
| `--base-directory` | Description | Path to root of of templates directory |
| | Valid | `String` |
| | Default | |
| `--compile-parameters` | Description | Pass template compile time parameters directly |
| | Valid | `Bogo::Smash` |
| | Default | |
| `--config` | Description | Configuration file path |
| | Valid | `String` |
| | Default | |
| `--credentials` | Description | Provider credentials (Key:Value[,Key:Value,...]) |
| | Valid | `Bogo::Smash` |
| | Default | |
| `--debug` | Description | Enable debug output |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | |
| `--defaults` | Description | Automatically accept default values |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | |
| `--diffs` | Description | Show planner content diff |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | |
| `--file` | Description | Path to template file |
| | Valid | `String` |
| | Default | |
| `--file-path-prompt` | Description | Enable interactive prompt for template path discovery |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | true|
| `--ignore-parameters` | Description | Parameters to ignore during modifications |
| | Valid | `String` |
| | Default | |
| `--interactive-parameters` | Description | Prompt for template parameters |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | true|
| `--merge-api-options` | Description | Merge API options defined within configuration on update |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | false|
| `--nesting-bucket` | Description | Bucket to use for storing nested stack templates |
| | Valid | `String` |
| | Default | |
| `--nesting-prefix` | Description | File name prefix for storing template in bucket |
| | Valid | `String` |
| | Default | |
| `--no-base-directory` | Description | Unset any value used for the template root directory path |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | |
| `--notification-topics` | Description | Notification endpoints for stack events |
| | Valid | `String` |
| | Default | |
| `--options` | Description | Extra options to apply to the API call (Key:Value[,Key:Value,...]) |
| | Valid | `Bogo::Smash` |
| | Default | |
| `--parameter` | Description | [DEPRECATED - use `parameters`] Pass template parameters directly (ParamName:ParamValue) |
| | Valid | `Bogo::Smash` |
| | Default | |
| `--parameter-validation` | Description | Stack parameter validation behavior |
| | Valid | `String` |
| | Default | "default"|
| `--parameters` | Description | Pass template parameters directly (Key:Value[,Key:Value,...]) |
| | Valid | `Bogo::Smash` |
| | Default | |
| `--plan` | Description | Provide planning information prior to update |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | true|
| `--plan-only` | Description | Exit after plan display |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | false|
| `--poll` | Description | Poll stack events on modification actions |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | true|
| `--print-only` | Description | Print the resulting stack template |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | |
| `--processing` | Description | Call the unicorns and explode the glitter bombs |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | true|
| `--rollback` | Description | Rollback stack on failure |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | |
| `--sparkle-pack` | Description | Load SparklePack gem |
| | Valid | `String` |
| | Default | |
| `--timeout` | Description | Seconds to wait for stack to complete |
| | Valid | `Integer` |
| | Default | |
| `--translate` | Description | Translate generated template to given provider |
| | Valid | `String` |
| | Default | |
| `--translate-chunk` | Description | Chunk length for serialization |
| | Valid | `Integer` |
| | Default | |
| `--upload-root-template` | Description | Upload root template to storage bucket |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | |
| `--yes` | Description | Automatically accept any requests for confirmation |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | |

## Describe Command

~~~
$ sfn describe
~~~

| Option | Attribute | Value
|--------|-----------|------
| `--conf` | Description |  |
| | Valid | `Sfn::Config::Conf` |
| | Default | |
| `--config` | Description | Configuration file path |
| | Valid | `String` |
| | Default | |
| `--create` | Description |  |
| | Valid | `Sfn::Config::Create` |
| | Default | |
| `--credentials` | Description | Provider credentials (Key:Value[,Key:Value,...]) |
| | Valid | `Bogo::Smash` |
| | Default | |
| `--debug` | Description | Enable debug output |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | |
| `--defaults` | Description | Automatically accept default values |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | |
| `--destroy` | Description |  |
| | Valid | `Sfn::Config::Destroy` |
| | Default | |
| `--events` | Description |  |
| | Valid | `Sfn::Config::Events` |
| | Default | |
| `--export` | Description |  |
| | Valid | `Sfn::Config::Export` |
| | Default | |
| `--ignore-parameters` | Description | Parameters to ignore during modifications |
| | Valid | `String` |
| | Default | |
| `--import` | Description |  |
| | Valid | `Sfn::Config::Import` |
| | Default | |
| `--inspect` | Description |  |
| | Valid | `Sfn::Config::Inspect` |
| | Default | |
| `--interactive-parameters` | Description | Prompt for template parameters |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | true|
| `--outputs` | Description | Display stack outputs |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | |
| `--poll` | Description | Poll stack events on modification actions |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | true|
| `--resources` | Description | Display stack resource list |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | |
| `--tags` | Description | Display stack tags |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | |
| `--update` | Description |  |
| | Valid | `Sfn::Config::Update` |
| | Default | |
| `--yes` | Description | Automatically accept any requests for confirmation |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | |

## Destroy Command

~~~
$ sfn destroy
~~~

| Option | Attribute | Value
|--------|-----------|------
| `--conf` | Description |  |
| | Valid | `Sfn::Config::Conf` |
| | Default | |
| `--config` | Description | Configuration file path |
| | Valid | `String` |
| | Default | |
| `--create` | Description |  |
| | Valid | `Sfn::Config::Create` |
| | Default | |
| `--credentials` | Description | Provider credentials (Key:Value[,Key:Value,...]) |
| | Valid | `Bogo::Smash` |
| | Default | |
| `--debug` | Description | Enable debug output |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | |
| `--defaults` | Description | Automatically accept default values |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | |
| `--ignore-parameters` | Description | Parameters to ignore during modifications |
| | Valid | `String` |
| | Default | |
| `--interactive-parameters` | Description | Prompt for template parameters |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | true|
| `--poll` | Description | Poll stack events on modification actions |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | true|
| `--update` | Description |  |
| | Valid | `Sfn::Config::Update` |
| | Default | |
| `--yes` | Description | Automatically accept any requests for confirmation |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | |

## Diff Command

~~~
$ sfn diff
~~~

| Option | Attribute | Value
|--------|-----------|------
| `--apply-mapping` | Description | Customize apply stack mapping as [StackName__]OutputName:ParameterName (Key:Value[,Key:Value,...]) |
| | Valid | `Bogo::Smash` |
| | Default | |
| `--apply-nesting` | Description | Apply stack nesting |
| | Valid | `String`, `Symbol` |
| | Default | "deep"|
| `--apply-stack` | Description | Apply outputs from stack to input parameters |
| | Valid | `String` |
| | Default | |
| `--base-directory` | Description | Path to root of of templates directory |
| | Valid | `String` |
| | Default | |
| `--compile-parameters` | Description | Pass template compile time parameters directly |
| | Valid | `Bogo::Smash` |
| | Default | |
| `--config` | Description | Configuration file path |
| | Valid | `String` |
| | Default | |
| `--credentials` | Description | Provider credentials (Key:Value[,Key:Value,...]) |
| | Valid | `Bogo::Smash` |
| | Default | |
| `--debug` | Description | Enable debug output |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | |
| `--defaults` | Description | Automatically accept default values |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | |
| `--diffs` | Description | Show planner content diff |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | |
| `--file` | Description | Path to template file |
| | Valid | `String` |
| | Default | |
| `--file-path-prompt` | Description | Enable interactive prompt for template path discovery |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | true|
| `--ignore-parameters` | Description | Parameters to ignore during modifications |
| | Valid | `String` |
| | Default | |
| `--interactive-parameters` | Description | Prompt for template parameters |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | true|
| `--merge-api-options` | Description | Merge API options defined within configuration on update |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | false|
| `--nesting-bucket` | Description | Bucket to use for storing nested stack templates |
| | Valid | `String` |
| | Default | |
| `--nesting-prefix` | Description | File name prefix for storing template in bucket |
| | Valid | `String` |
| | Default | |
| `--no-base-directory` | Description | Unset any value used for the template root directory path |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | |
| `--parameter` | Description | [DEPRECATED - use `parameters`] Pass template parameters directly (ParamName:ParamValue) |
| | Valid | `Bogo::Smash` |
| | Default | |
| `--parameter-validation` | Description | Stack parameter validation behavior |
| | Valid | `String` |
| | Default | "default"|
| `--parameters` | Description | Pass template parameters directly (Key:Value[,Key:Value,...]) |
| | Valid | `Bogo::Smash` |
| | Default | |
| `--plan` | Description | Provide planning information prior to update |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | true|
| `--plan-only` | Description | Exit after plan display |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | false|
| `--poll` | Description | Poll stack events on modification actions |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | true|
| `--print-only` | Description | Print the resulting stack template |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | |
| `--processing` | Description | Call the unicorns and explode the glitter bombs |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | true|
| `--raw-diff` | Description | Display raw diff information |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | false|
| `--sparkle-pack` | Description | Load SparklePack gem |
| | Valid | `String` |
| | Default | |
| `--translate` | Description | Translate generated template to given provider |
| | Valid | `String` |
| | Default | |
| `--translate-chunk` | Description | Chunk length for serialization |
| | Valid | `Integer` |
| | Default | |
| `--upload-root-template` | Description | Upload root template to storage bucket |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | |
| `--yes` | Description | Automatically accept any requests for confirmation |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | |

## Events Command

~~~
$ sfn events
~~~

| Option | Attribute | Value
|--------|-----------|------
| `--all-attributes` | Description | Display all event attributes |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | |
| `--all-events` | Description | Display all available events |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | |
| `--attribute` | Description | Event attribute to display |
| | Valid | `String` |
| | Default | |
| `--conf` | Description |  |
| | Valid | `Sfn::Config::Conf` |
| | Default | |
| `--config` | Description | Configuration file path |
| | Valid | `String` |
| | Default | |
| `--create` | Description |  |
| | Valid | `Sfn::Config::Create` |
| | Default | |
| `--credentials` | Description | Provider credentials (Key:Value[,Key:Value,...]) |
| | Valid | `Bogo::Smash` |
| | Default | |
| `--debug` | Description | Enable debug output |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | |
| `--defaults` | Description | Automatically accept default values |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | |
| `--destroy` | Description |  |
| | Valid | `Sfn::Config::Destroy` |
| | Default | |
| `--ignore-parameters` | Description | Parameters to ignore during modifications |
| | Valid | `String` |
| | Default | |
| `--interactive-parameters` | Description | Prompt for template parameters |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | true|
| `--poll` | Description | Poll stack events on modification actions |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | true|
| `--poll-delay` | Description | Seconds to pause between each event poll |
| | Valid | `Integer` |
| | Default | 20|
| `--update` | Description |  |
| | Valid | `Sfn::Config::Update` |
| | Default | |
| `--yes` | Description | Automatically accept any requests for confirmation |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | |

## Export Command

~~~
$ sfn export
~~~

| Option | Attribute | Value
|--------|-----------|------
| `--bucket` | Description | Remote storage bucket |
| | Valid | `String` |
| | Default | |
| `--bucket-prefix` | Description | Remote key prefix within bucket for dump file |
| | Valid | `String` |
| | Default | |
| `--conf` | Description |  |
| | Valid | `Sfn::Config::Conf` |
| | Default | |
| `--config` | Description | Configuration file path |
| | Valid | `String` |
| | Default | |
| `--create` | Description |  |
| | Valid | `Sfn::Config::Create` |
| | Default | |
| `--credentials` | Description | Provider credentials (Key:Value[,Key:Value,...]) |
| | Valid | `Bogo::Smash` |
| | Default | |
| `--debug` | Description | Enable debug output |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | |
| `--defaults` | Description | Automatically accept default values |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | |
| `--destroy` | Description |  |
| | Valid | `Sfn::Config::Destroy` |
| | Default | |
| `--events` | Description |  |
| | Valid | `Sfn::Config::Events` |
| | Default | |
| `--ignore-parameters` | Description | Parameters to ignore during modifications |
| | Valid | `String` |
| | Default | |
| `--interactive-parameters` | Description | Prompt for template parameters |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | true|
| `--name` | Description | Export file base name |
| | Valid | `String` |
| | Default | |
| `--path` | Description | Local path prefix for dump file |
| | Valid | `String` |
| | Default | |
| `--poll` | Description | Poll stack events on modification actions |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | true|
| `--update` | Description |  |
| | Valid | `Sfn::Config::Update` |
| | Default | |
| `--yes` | Description | Automatically accept any requests for confirmation |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | |

## Graph Command

~~~
$ sfn graph
~~~

| Option | Attribute | Value
|--------|-----------|------
| `--apply-nesting` | Description | Apply stack nesting |
| | Valid | `String`, `Symbol` |
| | Default | "deep"|
| `--base-directory` | Description | Path to root of of templates directory |
| | Valid | `String` |
| | Default | |
| `--compile-parameters` | Description | Pass template compile time parameters directly |
| | Valid | `Bogo::Smash` |
| | Default | |
| `--config` | Description | Configuration file path |
| | Valid | `String` |
| | Default | |
| `--credentials` | Description | Provider credentials (Key:Value[,Key:Value,...]) |
| | Valid | `Bogo::Smash` |
| | Default | |
| `--debug` | Description | Enable debug output |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | |
| `--defaults` | Description | Automatically accept default values |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | |
| `--file` | Description | Path to template file |
| | Valid | `String` |
| | Default | |
| `--file-path-prompt` | Description | Enable interactive prompt for template path discovery |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | true|
| `--graph-style` | Description | Style of graph (`dependency`, `creation`) |
| | Valid | `String` |
| | Default | "creation"|
| `--ignore-parameters` | Description | Parameters to ignore during modifications |
| | Valid | `String` |
| | Default | |
| `--interactive-parameters` | Description | Prompt for template parameters |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | true|
| `--luckymike` | Description | Force `dependency` style graph |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | false|
| `--nesting-bucket` | Description | Bucket to use for storing nested stack templates |
| | Valid | `String` |
| | Default | |
| `--nesting-prefix` | Description | File name prefix for storing template in bucket |
| | Valid | `String` |
| | Default | |
| `--no-base-directory` | Description | Unset any value used for the template root directory path |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | |
| `--output-file` | Description | Directory to write graph files |
| | Valid | `String` |
| | Default | "/home/spox/Projects/sparkleformation/sfn/sfn-graph"|
| `--output-type` | Description | File output type (Requires graphviz package for non-dot types) |
| | Valid | `String` |
| | Default | "dot"|
| `--poll` | Description | Poll stack events on modification actions |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | true|
| `--print-only` | Description | Print the resulting stack template |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | |
| `--processing` | Description | Call the unicorns and explode the glitter bombs |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | true|
| `--sparkle-pack` | Description | Load SparklePack gem |
| | Valid | `String` |
| | Default | |
| `--translate` | Description | Translate generated template to given provider |
| | Valid | `String` |
| | Default | |
| `--translate-chunk` | Description | Chunk length for serialization |
| | Valid | `Integer` |
| | Default | |
| `--upload-root-template` | Description | Upload root template to storage bucket |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | |
| `--yes` | Description | Automatically accept any requests for confirmation |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | |

## Import Command

~~~
$ sfn import
~~~

| Option | Attribute | Value
|--------|-----------|------
| `--bucket` | Description | Remote storage bucket JSON export files are located |
| | Valid | `String` |
| | Default | |
| `--bucket-prefix` | Description | Remote key prefix within bucket for dump file |
| | Valid | `String` |
| | Default | |
| `--conf` | Description |  |
| | Valid | `Sfn::Config::Conf` |
| | Default | |
| `--config` | Description | Configuration file path |
| | Valid | `String` |
| | Default | |
| `--create` | Description |  |
| | Valid | `Sfn::Config::Create` |
| | Default | |
| `--credentials` | Description | Provider credentials (Key:Value[,Key:Value,...]) |
| | Valid | `Bogo::Smash` |
| | Default | |
| `--debug` | Description | Enable debug output |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | |
| `--defaults` | Description | Automatically accept default values |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | |
| `--destroy` | Description |  |
| | Valid | `Sfn::Config::Destroy` |
| | Default | |
| `--events` | Description |  |
| | Valid | `Sfn::Config::Events` |
| | Default | |
| `--export` | Description |  |
| | Valid | `Sfn::Config::Export` |
| | Default | |
| `--ignore-parameters` | Description | Parameters to ignore during modifications |
| | Valid | `String` |
| | Default | |
| `--interactive-parameters` | Description | Prompt for template parameters |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | true|
| `--path` | Description | Directory path JSON export files are located |
| | Valid | `String` |
| | Default | |
| `--poll` | Description | Poll stack events on modification actions |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | true|
| `--update` | Description |  |
| | Valid | `Sfn::Config::Update` |
| | Default | |
| `--yes` | Description | Automatically accept any requests for confirmation |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | |

## Init Command

~~~
$ sfn init
~~~

| Option | Attribute | Value
|--------|-----------|------
| `--conf` | Description |  |
| | Valid | `Sfn::Config::Conf` |
| | Default | |
| `--config` | Description | Configuration file path |
| | Valid | `String` |
| | Default | |
| `--create` | Description |  |
| | Valid | `Sfn::Config::Create` |
| | Default | |
| `--credentials` | Description | Provider credentials (Key:Value[,Key:Value,...]) |
| | Valid | `Bogo::Smash` |
| | Default | |
| `--debug` | Description | Enable debug output |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | |
| `--defaults` | Description | Automatically accept default values |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | |
| `--describe` | Description |  |
| | Valid | `Sfn::Config::Describe` |
| | Default | |
| `--destroy` | Description |  |
| | Valid | `Sfn::Config::Destroy` |
| | Default | |
| `--events` | Description |  |
| | Valid | `Sfn::Config::Events` |
| | Default | |
| `--export` | Description |  |
| | Valid | `Sfn::Config::Export` |
| | Default | |
| `--ignore-parameters` | Description | Parameters to ignore during modifications |
| | Valid | `String` |
| | Default | |
| `--import` | Description |  |
| | Valid | `Sfn::Config::Import` |
| | Default | |
| `--inspect` | Description |  |
| | Valid | `Sfn::Config::Inspect` |
| | Default | |
| `--interactive-parameters` | Description | Prompt for template parameters |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | true|
| `--list` | Description |  |
| | Valid | `Sfn::Config::List` |
| | Default | |
| `--poll` | Description | Poll stack events on modification actions |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | true|
| `--promote` | Description |  |
| | Valid | `Sfn::Config::Promote` |
| | Default | |
| `--update` | Description |  |
| | Valid | `Sfn::Config::Update` |
| | Default | |
| `--validate` | Description |  |
| | Valid | `Sfn::Config::Validate` |
| | Default | |
| `--yes` | Description | Automatically accept any requests for confirmation |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | |

## Inspect Command

~~~
$ sfn inspect
~~~

| Option | Attribute | Value
|--------|-----------|------
| `--attribute` | Description | Dot delimited attribute to view |
| | Valid | `String` |
| | Default | |
| `--conf` | Description |  |
| | Valid | `Sfn::Config::Conf` |
| | Default | |
| `--config` | Description | Configuration file path |
| | Valid | `String` |
| | Default | |
| `--create` | Description |  |
| | Valid | `Sfn::Config::Create` |
| | Default | |
| `--credentials` | Description | Provider credentials (Key:Value[,Key:Value,...]) |
| | Valid | `Bogo::Smash` |
| | Default | |
| `--debug` | Description | Enable debug output |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | |
| `--defaults` | Description | Automatically accept default values |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | |
| `--destroy` | Description |  |
| | Valid | `Sfn::Config::Destroy` |
| | Default | |
| `--events` | Description |  |
| | Valid | `Sfn::Config::Events` |
| | Default | |
| `--export` | Description |  |
| | Valid | `Sfn::Config::Export` |
| | Default | |
| `--failure-log-path` | Description | Path to remote log file for display on failure |
| | Valid | `String` |
| | Default | "/var/log/chef/client.log"|
| `--identity-file` | Description | SSH identity file for authentication |
| | Valid | `String` |
| | Default | |
| `--ignore-parameters` | Description | Parameters to ignore during modifications |
| | Valid | `String` |
| | Default | |
| `--import` | Description |  |
| | Valid | `Sfn::Config::Import` |
| | Default | |
| `--instance-failure` | Description | Display log file error from failed not if possible |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | |
| `--interactive-parameters` | Description | Prompt for template parameters |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | true|
| `--load-balancers` | Description | Locate all load balancers, display addresses and server states |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | |
| `--nodes` | Description | Locate all instances and display addresses |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | |
| `--poll` | Description | Poll stack events on modification actions |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | true|
| `--ssh-user` | Description | SSH username for inspection connect |
| | Valid | `String` |
| | Default | |
| `--update` | Description |  |
| | Valid | `Sfn::Config::Update` |
| | Default | |
| `--yes` | Description | Automatically accept any requests for confirmation |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | |

## List Command

~~~
$ sfn list
~~~

| Option | Attribute | Value
|--------|-----------|------
| `--all-attributes` | Description | Print all available attributes |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | |
| `--attribute` | Description | Attribute of stack to print |
| | Valid | `String` |
| | Default | |
| `--conf` | Description |  |
| | Valid | `Sfn::Config::Conf` |
| | Default | |
| `--config` | Description | Configuration file path |
| | Valid | `String` |
| | Default | |
| `--create` | Description |  |
| | Valid | `Sfn::Config::Create` |
| | Default | |
| `--credentials` | Description | Provider credentials (Key:Value[,Key:Value,...]) |
| | Valid | `Bogo::Smash` |
| | Default | |
| `--debug` | Description | Enable debug output |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | |
| `--defaults` | Description | Automatically accept default values |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | |
| `--describe` | Description |  |
| | Valid | `Sfn::Config::Describe` |
| | Default | |
| `--destroy` | Description |  |
| | Valid | `Sfn::Config::Destroy` |
| | Default | |
| `--events` | Description |  |
| | Valid | `Sfn::Config::Events` |
| | Default | |
| `--export` | Description |  |
| | Valid | `Sfn::Config::Export` |
| | Default | |
| `--ignore-parameters` | Description | Parameters to ignore during modifications |
| | Valid | `String` |
| | Default | |
| `--import` | Description |  |
| | Valid | `Sfn::Config::Import` |
| | Default | |
| `--inspect` | Description |  |
| | Valid | `Sfn::Config::Inspect` |
| | Default | |
| `--interactive-parameters` | Description | Prompt for template parameters |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | true|
| `--poll` | Description | Poll stack events on modification actions |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | true|
| `--status` | Description | Match stacks with given status. Use "none" to disable. |
| | Valid | `String` |
| | Default | |
| `--update` | Description |  |
| | Valid | `Sfn::Config::Update` |
| | Default | |
| `--yes` | Description | Automatically accept any requests for confirmation |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | |

## Print Command

~~~
$ sfn print
~~~

| Option | Attribute | Value
|--------|-----------|------
| `--apply-nesting` | Description | Apply stack nesting |
| | Valid | `String`, `Symbol` |
| | Default | "deep"|
| `--base-directory` | Description | Path to root of of templates directory |
| | Valid | `String` |
| | Default | |
| `--compile-parameters` | Description | Pass template compile time parameters directly |
| | Valid | `Bogo::Smash` |
| | Default | |
| `--config` | Description | Configuration file path |
| | Valid | `String` |
| | Default | |
| `--credentials` | Description | Provider credentials (Key:Value[,Key:Value,...]) |
| | Valid | `Bogo::Smash` |
| | Default | |
| `--debug` | Description | Enable debug output |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | |
| `--defaults` | Description | Automatically accept default values |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | |
| `--file` | Description | Path to template file |
| | Valid | `String` |
| | Default | |
| `--file-path-prompt` | Description | Enable interactive prompt for template path discovery |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | true|
| `--ignore-parameters` | Description | Parameters to ignore during modifications |
| | Valid | `String` |
| | Default | |
| `--interactive-parameters` | Description | Prompt for template parameters |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | true|
| `--nesting-bucket` | Description | Bucket to use for storing nested stack templates |
| | Valid | `String` |
| | Default | |
| `--nesting-prefix` | Description | File name prefix for storing template in bucket |
| | Valid | `String` |
| | Default | |
| `--no-base-directory` | Description | Unset any value used for the template root directory path |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | |
| `--poll` | Description | Poll stack events on modification actions |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | true|
| `--print-only` | Description | Print the resulting stack template |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | |
| `--processing` | Description | Call the unicorns and explode the glitter bombs |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | true|
| `--sparkle-dump` | Description | Do not use provider customized dump behavior |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | |
| `--sparkle-pack` | Description | Load SparklePack gem |
| | Valid | `String` |
| | Default | |
| `--translate` | Description | Translate generated template to given provider |
| | Valid | `String` |
| | Default | |
| `--translate-chunk` | Description | Chunk length for serialization |
| | Valid | `Integer` |
| | Default | |
| `--upload-root-template` | Description | Upload root template to storage bucket |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | |
| `--write-to-file` | Description | Write compiled SparkleFormation template to path provided |
| | Valid | `String` |
| | Default | |
| `--yes` | Description | Automatically accept any requests for confirmation |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | |

## Promote Command

~~~
$ sfn promote
~~~

| Option | Attribute | Value
|--------|-----------|------
| `--accounts` | Description | JSON accounts file path |
| | Valid | `String` |
| | Default | |
| `--bucket` | Description | Bucket name containing the exports |
| | Valid | `String` |
| | Default | |
| `--bucket-prefix` | Description | Key prefix within remote bucket |
| | Valid | `String` |
| | Default | |
| `--conf` | Description |  |
| | Valid | `Sfn::Config::Conf` |
| | Default | |
| `--config` | Description | Configuration file path |
| | Valid | `String` |
| | Default | |
| `--create` | Description |  |
| | Valid | `Sfn::Config::Create` |
| | Default | |
| `--credentials` | Description | Provider credentials (Key:Value[,Key:Value,...]) |
| | Valid | `Bogo::Smash` |
| | Default | |
| `--debug` | Description | Enable debug output |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | |
| `--defaults` | Description | Automatically accept default values |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | |
| `--describe` | Description |  |
| | Valid | `Sfn::Config::Describe` |
| | Default | |
| `--destroy` | Description |  |
| | Valid | `Sfn::Config::Destroy` |
| | Default | |
| `--events` | Description |  |
| | Valid | `Sfn::Config::Events` |
| | Default | |
| `--export` | Description |  |
| | Valid | `Sfn::Config::Export` |
| | Default | |
| `--ignore-parameters` | Description | Parameters to ignore during modifications |
| | Valid | `String` |
| | Default | |
| `--import` | Description |  |
| | Valid | `Sfn::Config::Import` |
| | Default | |
| `--inspect` | Description |  |
| | Valid | `Sfn::Config::Inspect` |
| | Default | |
| `--interactive-parameters` | Description | Prompt for template parameters |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | true|
| `--list` | Description |  |
| | Valid | `Sfn::Config::List` |
| | Default | |
| `--poll` | Description | Poll stack events on modification actions |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | true|
| `--update` | Description |  |
| | Valid | `Sfn::Config::Update` |
| | Default | |
| `--yes` | Description | Automatically accept any requests for confirmation |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | |

## Update Command

~~~
$ sfn update
~~~

| Option | Attribute | Value
|--------|-----------|------
| `--apply-mapping` | Description | Customize apply stack mapping as [StackName__]OutputName:ParameterName (Key:Value[,Key:Value,...]) |
| | Valid | `Bogo::Smash` |
| | Default | |
| `--apply-nesting` | Description | Apply stack nesting |
| | Valid | `String`, `Symbol` |
| | Default | "deep"|
| `--apply-stack` | Description | Apply outputs from stack to input parameters |
| | Valid | `String` |
| | Default | |
| `--base-directory` | Description | Path to root of of templates directory |
| | Valid | `String` |
| | Default | |
| `--compile-parameters` | Description | Pass template compile time parameters directly |
| | Valid | `Bogo::Smash` |
| | Default | |
| `--config` | Description | Configuration file path |
| | Valid | `String` |
| | Default | |
| `--credentials` | Description | Provider credentials (Key:Value[,Key:Value,...]) |
| | Valid | `Bogo::Smash` |
| | Default | |
| `--debug` | Description | Enable debug output |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | |
| `--defaults` | Description | Automatically accept default values |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | |
| `--diffs` | Description | Show planner content diff |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | |
| `--file` | Description | Path to template file |
| | Valid | `String` |
| | Default | |
| `--file-path-prompt` | Description | Enable interactive prompt for template path discovery |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | true|
| `--ignore-parameters` | Description | Parameters to ignore during modifications |
| | Valid | `String` |
| | Default | |
| `--interactive-parameters` | Description | Prompt for template parameters |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | true|
| `--merge-api-options` | Description | Merge API options defined within configuration on update |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | false|
| `--nesting-bucket` | Description | Bucket to use for storing nested stack templates |
| | Valid | `String` |
| | Default | |
| `--nesting-prefix` | Description | File name prefix for storing template in bucket |
| | Valid | `String` |
| | Default | |
| `--no-base-directory` | Description | Unset any value used for the template root directory path |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | |
| `--parameter` | Description | [DEPRECATED - use `parameters`] Pass template parameters directly (ParamName:ParamValue) |
| | Valid | `Bogo::Smash` |
| | Default | |
| `--parameter-validation` | Description | Stack parameter validation behavior |
| | Valid | `String` |
| | Default | "default"|
| `--parameters` | Description | Pass template parameters directly (Key:Value[,Key:Value,...]) |
| | Valid | `Bogo::Smash` |
| | Default | |
| `--plan` | Description | Provide planning information prior to update |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | true|
| `--plan-only` | Description | Exit after plan display |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | false|
| `--poll` | Description | Poll stack events on modification actions |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | true|
| `--print-only` | Description | Print the resulting stack template |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | |
| `--processing` | Description | Call the unicorns and explode the glitter bombs |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | true|
| `--sparkle-pack` | Description | Load SparklePack gem |
| | Valid | `String` |
| | Default | |
| `--translate` | Description | Translate generated template to given provider |
| | Valid | `String` |
| | Default | |
| `--translate-chunk` | Description | Chunk length for serialization |
| | Valid | `Integer` |
| | Default | |
| `--upload-root-template` | Description | Upload root template to storage bucket |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | |
| `--yes` | Description | Automatically accept any requests for confirmation |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | |

## Validate Command

~~~
$ sfn validate
~~~

| Option | Attribute | Value
|--------|-----------|------
| `--apply-nesting` | Description | Apply stack nesting |
| | Valid | `String`, `Symbol` |
| | Default | "deep"|
| `--base-directory` | Description | Path to root of of templates directory |
| | Valid | `String` |
| | Default | |
| `--compile-parameters` | Description | Pass template compile time parameters directly |
| | Valid | `Bogo::Smash` |
| | Default | |
| `--config` | Description | Configuration file path |
| | Valid | `String` |
| | Default | |
| `--credentials` | Description | Provider credentials (Key:Value[,Key:Value,...]) |
| | Valid | `Bogo::Smash` |
| | Default | |
| `--debug` | Description | Enable debug output |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | |
| `--defaults` | Description | Automatically accept default values |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | |
| `--file` | Description | Path to template file |
| | Valid | `String` |
| | Default | |
| `--file-path-prompt` | Description | Enable interactive prompt for template path discovery |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | true|
| `--ignore-parameters` | Description | Parameters to ignore during modifications |
| | Valid | `String` |
| | Default | |
| `--interactive-parameters` | Description | Prompt for template parameters |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | true|
| `--nesting-bucket` | Description | Bucket to use for storing nested stack templates |
| | Valid | `String` |
| | Default | |
| `--nesting-prefix` | Description | File name prefix for storing template in bucket |
| | Valid | `String` |
| | Default | |
| `--no-base-directory` | Description | Unset any value used for the template root directory path |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | |
| `--poll` | Description | Poll stack events on modification actions |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | true|
| `--print-only` | Description | Print the resulting stack template |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | |
| `--processing` | Description | Call the unicorns and explode the glitter bombs |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | true|
| `--sparkle-pack` | Description | Load SparklePack gem |
| | Valid | `String` |
| | Default | |
| `--translate` | Description | Translate generated template to given provider |
| | Valid | `String` |
| | Default | |
| `--translate-chunk` | Description | Chunk length for serialization |
| | Valid | `Integer` |
| | Default | |
| `--upload-root-template` | Description | Upload root template to storage bucket |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | |
| `--yes` | Description | Automatically accept any requests for confirmation |
| | Valid | `TrueClass`, `FalseClass` |
| | Default | |

