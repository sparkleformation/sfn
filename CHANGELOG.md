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
