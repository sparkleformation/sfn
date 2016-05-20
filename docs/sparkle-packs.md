---
title: "SparklePacks"
weight: 6
anchors:
  - title: "Enabling SparklePacks"
    url: "#enabling-sparklepacks"
---

## What is a SparklePack?

SparklePacks are implemented as a feature of the SparkleFormation library,
providing a means to package SparkleFormation building blocks
and templates as reusable, redistributable software artifacts.
A SparklePack may package up any combination of SparkleFormation
[building blocks](http://www.sparkleformation.io/docs/sparkle_formation/building-blocks.html) and templates.

sfn supports loading SparklePacks distributed as [Ruby gems](http://www.sparkleformation.io/docs/sparkle_formation/sparkle-packs.html#distribution).
You can find published SparklePacks on the RubyGems site by
[searching for the sparkle-pack prefix](https://rubygems.org/search?query=sparkle-pack).

### Enabling SparklePacks

The following examples use the [sparkle-pack-aws-availability-zones](https://rubygems.org/gems/sparkle-pack-aws-availability-zones) gem.
In reviewing [the source code of that project on Github](https://github.com/hw-labs/sparkle-pack-aws-availability-zones),
note that it provides a [`zones` registry](https://github.com/hw-labs/sparkle-pack-aws-availability-zones/blob/v0.1.2/lib/sparkleformation/registry/get_azs.rb)
which uses the aws-sdk-core library to return an array of available AZs.

When using sfn with Bundler, we'll add any SparklePacks we
want to enable to the `sfn` group in our Gemfile:

~~~ruby
# Gemfile
source 'https://rubygems.org'

gem 'sfn'

group :sfn do
  gem 'sparkle-pack-aws-availability-zones'
end
~~~

After running `bundle`, the SparklePack is installed but not yet enabled:

~~~
$ cat sparkleformation/zones_test.rb
SparkleFormation.new(:zones_test) do
  zones registry!(:zones)
end

$ bundle exec sfn print --file zones_test
ERROR: SparkleFormation::Error::NotFound::Registry: Failed to locate item named: `zones`
~~~

Adding the gem to an array of `sparkle_packs` in
the `.sfn` configuration file will activate it for use:

~~~ruby
Configuration.new do
  sparkle_pack [ 'sparkle-pack-aws-availability-zones' ]
end
~~~

Invoking `zones` registry in the template is now functional:

~~~
$ bundle exec sfn print --file zones_test
{
  "Zones": [
    "us-east-1a",
    "us-east-1b",
    "us-east-1c",
    "us-east-1e"
  ]
}
~~~