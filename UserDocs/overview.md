---
title: "Overview"
weight: 1
---

# Overview

The SparkleFormation CLI (`sfn`) is a Ruby based command line interface
for interacting with remote orchestration API. It is an application
implementation of the SparkleFormation library and provides access to
all the underlying features provided by the SparkleFormation library.

## Feature Summary

Notable features available via the SparkleFormation CLI:

- SparkleFormation template processing
- Template processing helpers
- Custom callback support
- Remote orchestration API support
  - AWS CloudFormation
  - Eucalyptus
  - Rackspace Orchestration
  - OpenStack Heat
  - Google Cloud Deployment Manager
- Chef `knife` plugin support
- Deep resource inspection

## Installation

The SparkleFormation CLI is available from [Ruby Gems](https://rubygems.org/gems/sfn). To install, simply execute:

~~~sh
$ gem install sfn
~~~

or, if you use [Bundler](http://bundler.io/), add the following to your Gemfile:

~~~sh
gem 'sfn'
~~~

See [Configuration](configuration.md) and [Usage](usage.md) for further instructions.
