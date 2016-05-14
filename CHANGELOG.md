# v3.0.6
* [fix] Cast all value types to String within AWS planner (#194)
* [fix] Fix template names on create/update prompting (#197)
* [enhancement] Extend validation support for compile time parameters (#199)
* [enhancement] Add parameter validation control on stack updates (#198)
* [feature] Support remote locations when using apply stack (#196)

# v3.0.4
* [fix] Update parameter values extraction location in planner
* [fix] Merge compile time parameters when existing are available
* [enhancement] Reduce response size on event polling where available

# v3.0.2
* [fix] Properly scrub nested stack pseudo property on update (#189)
* [fix] Process nested stacks before removal within AWS planner (#190)
* [enhancement] Add configuration options for Google cloud (#188)

# v3.0.0
_Major release includes breaking changes!_
* [feature] Add support for Google Cloud Deployment Manager (#181)
* [feature] Add `--sparkle-dump` option for template printing (#181)
* [enhancement] Minimum constraint on sparkle_formation set to 3.0
* [enhancement] Enable automatic provider restrictions using credentials provider
* [enhancement] Restrict Bundler automatic gem loading to `:sfn` group only (#171)
* [enhancement] Support uploading root template to storage bucket (#179)
* [enhancement] Provider specific extension support (#181)
* [enhancement] Support custom apply stack mappings (#185)
* [enhancement] Update planner to use new SparkleFormation::Resources::Resource instances (#186)
 * Includes conditional logic support for property modification effects
* [fix] Mark AWS::EC2::Instance resources in planner on AWS::CloudFormation::Init modifications (#186)
* [fix] Set compile time stack parameters under logical name not stack name on update (#180)
* [task] Removal of `--translate` option for templates
* [task] Remove internal stack nesting implementation support

_NOTE: Breaking changes introduced via sparkle_formation 3.0 minimum constraint. Review
release sparkle_formation 3.0 release notes._

# v2.2.0
* [enhancement] Properly support list types when validating (#167)
* [enhancement] Restrict automatic gem loading when `:sfn` group is present (#175)
* [enhancement] Support loading configuration files with type extensions (#168)

# v2.1.12
* [fix] Provide useful error message when nesting_bucket is unset (#159)
* [fix] Properly locate templates when relative path provided (#160)
* [enhancement] Support plan only output on update via `--plan-only` (#158)
* [enhancement] Allow tag updates on stack updates via `--merge-api-options` (see: #154)
* [fix] Add `DependsOn` support to graph generation
* [enhancement] Provide "dependency" style graph option

# v2.1.10
* [fix] Prevent direct output key modification on graph mapping
* [enhancement] Restrict graph colors to readable values

# v2.1.8
* [fix] Fix some planner errors caused by unexpected types (#146)
* [fix] Use common stack scrubbing implementation for create and update (#148)
* [fix] Properly expand nested stacks when displaying events (#148)
* [enhancement] Update internal stack data caching to reduce request numbers and size (#148)
* [feature] Add initial graph command implementation (currenty AWS only) (#152)

# v2.1.6
* [fix] Prevent configuration defaults overwriting user defined values (#144)

# v2.1.4
* [fix] Update environment variable name used for azure credentials (#135)
* [fix] Cast all parameters to String types within planner (#137)
* [fix] Properly support compile time parameters via CLI (#141)
* [enhancement] Add diff output support to planner (#142)
* [enhancement] Support writing template to file via `print` command (#139)

# v2.1.2
* [enhancement] Include parameter name on error output when failed to receive (#116)
* [enhancement] Rescue planner errors and notify user. Allow update to proceed (#124)
* [feature] Add built-in callback for AWS MFA support (#123)
* [fix] Compare parameters values on updates as String type (#126)
* [fix] Remove policy modification on stack delete within AWS (#127)
* [feature] Support optional stack policy removal prior to update (#127)
* [feature] Add built-in callback for AWS Assume Role credential caching (#128)
* [feature] Add load balancer specific inspection (#129)

# v2.1.0
* [fix] Use SparkleFormation::Collection helper to ensure proper pack ordering (#115)
* [fix] Set minimum constraint on sparkle_formation library to 2.1.2

# v2.0.6
* [fix] Remove bundler assumption within `init` command (#114)

# v2.0.4
* [enhancement] Add `--debug` flag
* [enhancement] Allow nested stacks to be disabled (apply_nesting :none)

# v2.0.2
* [task] Remove deprecated capabilities flag (#106)
* [feature] Add `init` command for project initialization (#107)
* [enhancement] Add `debug` config option to enable UI debug output (#108)
* [fix] Fix hash type coerce of strings provided via CLI (#109)
* [enhancement] Support template parameter processing for supported providers (#110)

# v2.0.0
* [enhancement] Move to SparkleFormation 2.0
* [enhancement] Add more credential content to configuration file generator
* [feature] Run Bundler.require if Bundler is detected (#97)
* [enhancement] Extract provider specific details for abstracts (#98)
* [enhancement] Add `nesting_prefix` to customize nested template storage path (#99)
* [fix] Properly display substack planning information
* [fix] Force minimum width on list columns to prevent bunching on no content

# v1.2.0
* [fix] Always require packs when loading
* [fix] Prevent stale output display on update
* [enhancement] Coerce hash type configurations consistently
* [enhancement] Force short flags to prevent change

# v1.1.16
* [fix] Duplicate template when dereferencing within planner

# v1.1.14
* [fix] Use correct name part for building callback name

# v1.1.12
* [enhancement] Include updated time information on stack list
* [enhancement] Support pseudo-parameters in update planning
  * AWS only as it is currently the only implementation

# v1.1.10
* [enhancement] Better configuration related errors
* [fix] Planning display on stack removal (#75)
* [fix] Remove stack properties on update request (#76)
* [enhancement] Add `retries` config alias for `retry` (#77)

# v1.1.8
* [fix] Disable knife config mashing to get expected values (#72)
* [feature] Add new `conf` command (#72)
* [feature] Add planning support for stack updates (#69)

# v1.1.6
* [fix] set proper parameter hash on apply stack (#67)

# v1.1.4
* [feature] Add new `diff` command

# v1.1.2
* [fix] stack update when extracting compile time state
* [fix] remove use of `root_path` method when shallow nesting is in use

# v1.1.0
* Add support for compile time parameters
* Fix valid stack type check on child stack connections
* Provide output context for template location when prompting parameters
* Use full stack path naming for bucket file names when storing

# v1.0.4
* [fix] Set template prior to apply on update to find new parameters
* Disable parameter validation warning on deep nesting
* Update parameter detection on updates when using deep nesting

# v1.0.2
* [fix] Properly detect local pack directory if available
* Add `print` command for printing generated templates
* Add support for custom stack resource types

# v1.0.0

_NOTE: This release contains breaking changes! Please review the
	changes in this release and test your configuration and
	templates. Changes that may introduce breakage have been
	labeled below._

* [BREAKING] Update sparkle_formation constraint to 1.0 versions
* [BREAKING] Default to "deep" style nesting (previous default: "shallow")
* [BREAKING] Template loading via SparklePacks in place of direct file loading
* Provide support for shallow and deep stack nesting styles
* Add support for customized callbacks
* Fix `--print-only` behavior on `update` command, add to `validate` command
* On validation of template with nesting, validate all nested templates _and_ root template
* Display details of all nested stacks on `describe` command
* Disable automatic stack inspection on failed `create` / `update` command
* Add support for SparklePacks
* Add support for AWS stack policies via optional callback
* And lots of internal refactors!

# v0.4.12
* Fix transient uninitialized constant error for update command

# v0.4.10
* Fix error when no options are provided within config (#18)
* Fix error when parameters originate from config only (#20)

# v0.4.8
* Disable delimiter on `:multiple` options (must specify multiple flags)
* Update types allowed by inspect for instance failure option
* Parameter hash is now always fully set based on template parameters

# v0.4.6
* Fix parameter generation from CLI

# v0.4.4
* Add a few more config fixes to properly validate

# v0.4.2
* Fix config types defined

# v0.4.0
* Fix parameters passed on CLI (#11)
* Fix credential overrides from the CLI (#14)
* Properly process CLI options through custom config classes
* Include AWS STS support via miasma-aws version bump

***NOTE***: Some CLI **short** flags have changed in this release. This is due to
	some updates on flag generation to help keep things more
	consistent now and into the future. Please refer to the help
	output for a given command to view short flags.

# v0.3.8
* Fix result output from `update` command (#9)
* Fix `inspect` command to properly support multiple attribute flags
* Only output JSON when using `--print-only` flag with `create` command (#10)

# v0.3.6
* Set options correctly on `sfn` executable (#7)
* Update cli library dependency to provide better error messages (#6)
* Update cloud library dependencies to support new options (:on_failure and :tags)
* Cloud library update also adds support for aws credentials file

# v0.3.4
* Default column widths when no output is available
* Display stack tags on `describe` command
* Fix apply stack reference to access via hash
* Validate stack is in `:create_complete` state when checking successful creation
* Fix path prompting (#5 thanks @JonathanSerafini)
* Update minimum CLI lib dependency to provide correct configuration merging (#4)

# v0.3.2
* Validate stack name prior to discovery on apply
* Update configuration usage to allow runtime modification
* Allow `create` command to print-only without requiring API credentials

# v0.3.0
* Conversion from `knife-cloudformation` to `sfn`
* Add knife subcommand alias `sparkleformation`
* Remove implementation dependency on Chef tooling

# v0.2.20
* Add automatic support for outputs in nested stacks to `--apply-stack`

# v0.2.18
* Fix nested stack URL generation

# v0.2.16
* Fix broken validation command (#12 thanks @JonathanSerafini)
* Pad stack name indexes when unpacked

# v0.2.14
* Pass command configuration through when unpacking
* Force stack list reload prior to polling to prevent lookup errors
* Add glob support on name arguments provided for `destroy`
* Add unpacked stack support to `--apply-stack` flag
* Retry events polling when started from different command

# v0.2.12
* Use template to provide logical parameter ordering on stack update
* Only set parameters when not the default template value
* Do not save nested stacks to remote bucket when in print-only mode
* Add initial support for un-nested stack create and update
* Fix nested stack flagging usage

# v0.2.10
* Add initial nested stack support

# v0.2.8
* Update stack lookup implementation to make faster from CLI
* Prevent constant error on exception when Redis is not in use
* Provide better error messages on request failures

# v0.2.6
* Update to parameter re-defaults to use correct hash instance

# v0.2.4
* Fix apply stack parameter processing

# v0.2.2
* Fix redis-objects loading in cache helper

# v0.2.0
* This release should be considered "breaking"
* Underlying cloud API has been changed from fog to miasma
* The `inspect` command has been fully reworked to support `--attribute`
* Lots and lots of other changes. See commit log.

# v0.1.22
* Prevent full stack list loading in knife commands
* Default logger to INFO level and allow DEBUG level via `ENV['DEBUG']`
* Fix assumption of type when accessing cached data (cannot assume availability)

# v0.1.20
* Update some caching behavior
* Add more logging especially around remote calls
* Add support for request throttling
* Disable local caching when stack is in `in_progress` state

# v0.1.18
* Replace constant with inline value to prevent warnings
* Explicitly load file to ensure proper load ordering

# v0.1.16
* Fix exit code on stack destroy
* Update stack loading for single stack requests
* Add import and export functionality

# v0.1.14
* Extract template building tools
* Add support for custom CF locations and prompting
* Updates in fetching and caching behavior

# v0.1.12
* Use the split value when re-joining parameters

# v0.1.10
* Fix parameter passing via the CLI (data loss issue when value contained ':')

# v0.1.8
* Update event cache handling
* Allow multiple users for node connect attempts

# v0.1.6
* Adds inspect action
* Updates to commons
* Allow multiple stack destroys at once
* Updates to options to make consistent

# v0.1.4
* Support outputs on stack creation
* Poll on destroy by default
* Add inspection helper for failed node inspection
* Refactor AWS interactions to common library

# v0.1.2
* Update dependency restriction to get later version

# v0.1.0
* Stable-ish release

# v0.0.1
* Initial release
