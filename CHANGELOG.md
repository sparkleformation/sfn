## v0.4.6
* Fix parameter generation from CLI

## v0.4.4
* Add a few more config fixes to properly validate

## v0.4.2
* Fix config types defined

## v0.4.0
* Fix parameters passed on CLI (#11)
* Fix credential overrides from the CLI (#14)
* Properly process CLI options through custom config classes
* Include AWS STS support via miasma-aws version bump

***NOTE***: Some CLI **short** flags have changed in this release. This is due to
	some updates on flag generation to help keep things more
	consistent now and into the future. Please refer to the help
	output for a given command to view short flags.

## v0.3.8
* Fix result output from `update` command (#9)
* Fix `inspect` command to properly support multiple attribute flags
* Only output JSON when using `--print-only` flag with `create` command (#10)

## v0.3.6
* Set options correctly on `sfn` executable (#7)
* Update cli library dependency to provide better error messages (#6)
* Update cloud library dependencies to support new options (:on_failure and :tags)
* Cloud library update also adds support for aws credentials file

## v0.3.4
* Default column widths when no output is available
* Display stack tags on `describe` command
* Fix apply stack reference to access via hash
* Validate stack is in `:create_complete` state when checking successful creation
* Fix path prompting (#5 thanks @JonathanSerafini)
* Update minimum CLI lib dependency to provide correct configuration merging (#4)

## v0.3.2
* Validate stack name prior to discovery on apply
* Update configuration usage to allow runtime modification
* Allow `create` command to print-only without requiring API credentials

## v0.3.0
* Conversion from `knife-cloudformation` to `sfn`
* Add knife subcommand alias `sparkleformation`
* Remove implementation dependency on Chef tooling

## v0.2.20
* Add automatic support for outputs in nested stacks to `--apply-stack`

## v0.2.18
* Fix nested stack URL generation

## v0.2.16
* Fix broken validation command (#12 thanks @JonathanSerafini)
* Pad stack name indexes when unpacked

## v0.2.14
* Pass command configuration through when unpacking
* Force stack list reload prior to polling to prevent lookup errors
* Add glob support on name arguments provided for `destroy`
* Add unpacked stack support to `--apply-stack` flag
* Retry events polling when started from different command

## v0.2.12
* Use template to provide logical parameter ordering on stack update
* Only set parameters when not the default template value
* Do not save nested stacks to remote bucket when in print-only mode
* Add initial support for un-nested stack create and update
* Fix nested stack flagging usage

## v0.2.10
* Add initial nested stack support

## v0.2.8
* Update stack lookup implementation to make faster from CLI
* Prevent constant error on exception when Redis is not in use
* Provide better error messages on request failures

## v0.2.6
* Update to parameter re-defaults to use correct hash instance

## v0.2.4
* Fix apply stack parameter processing

## v0.2.2
* Fix redis-objects loading in cache helper

## v0.2.0
* This release should be considered "breaking"
* Underlying cloud API has been changed from fog to miasma
* The `inspect` command has been fully reworked to support `--attribute`
* Lots and lots of other changes. See commit log.

## v0.1.22
* Prevent full stack list loading in knife commands
* Default logger to INFO level and allow DEBUG level via `ENV['DEBUG']`
* Fix assumption of type when accessing cached data (cannot assume availability)

## v0.1.20
* Update some caching behavior
* Add more logging especially around remote calls
* Add support for request throttling
* Disable local caching when stack is in `in_progress` state

## v0.1.18
* Replace constant with inline value to prevent warnings
* Explicitly load file to ensure proper load ordering

## v0.1.16
* Fix exit code on stack destroy
* Update stack loading for single stack requests
* Add import and export functionality

## v0.1.14
* Extract template building tools
* Add support for custom CF locations and prompting
* Updates in fetching and caching behavior

## v0.1.12
* Use the split value when re-joining parameters

## v0.1.10
* Fix parameter passing via the CLI (data loss issue when value contained ':')

## v0.1.8
* Update event cache handling
* Allow multiple users for node connect attempts

## v0.1.6
* Adds inspect action
* Updates to commons
* Allow multiple stack destroys at once
* Updates to options to make consistent

## v0.1.4
* Support outputs on stack creation
* Poll on destroy by default
* Add inspection helper for failed node inspection
* Refactor AWS interactions to common library

## v0.1.2
* Update dependency restriction to get later version

## v0.1.0
* Stable-ish release

## v0.0.1
* Initial release
