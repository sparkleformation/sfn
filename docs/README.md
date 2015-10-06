---
title: "Overview"
weight: 1
---

# Overview

The SparkleFormation CLI (`sfn`) is a Ruby based command line interface
for interacting with remote orchestration API. It is an application
implementation of the SparkleFormation library and provides access to
all the underlying features provided by the SparkleFormation library.

## Table of Contents

- [Feature Summary](#feature-summary)
- [Installation](#installation)
- [Configuration](configuration.html)
  - [sfn based](configuration#sfn-based)
  - [knife based](configuration#knife-based)
- [Usage](usage.html)
  - [Commands](usage#commands)
- [Callbacks](callbacks.html)
  - [Enabling Callbacks](callbacks#enabling-callbacks)
  - [Builtin Callbacks](callbacks#builtin-callbacks)
  - [Custom Callbacks](callbacks#custom-callbacks)

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
- Chef `knife` plugin support
- Deep resource inspection

## Installation

Sfn is available from [Ruby Gems](https://rubygems.org/gems/sfn). To install, simply execute:

~~~sh
$ gem install sfn
~~~

or, if you use [Bundler](http://bundler.io/), add the following to your Gemfile:

~~~sh
gem sfn', '~> 1.0.4'
~~~

See [Configuration](configuration.html) and [Usage](usage.html) for further instructions.
