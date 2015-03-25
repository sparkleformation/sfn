$LOAD_PATH.unshift File.expand_path(File.dirname(__FILE__)) + '/lib/'
require 'sfn/version'
Gem::Specification.new do |s|
  s.name = 'sfn'
  s.version = Sfn::VERSION.version
  s.summary = 'SparkleFormation CLI'
  s.author = 'Chris Roberts'
  s.email = 'code@chrisroberts.org'
  s.homepage = 'http://github.com/sparkleformation/sfn'
  s.description = 'SparkleFormation CLI'
  s.license = 'Apache-2.0'
  s.require_path = 'lib'
  s.add_dependency 'bogo-cli', '~> 0.1.12'
  s.add_dependency 'miasma'
  s.add_dependency 'net-ssh'
  s.add_dependency 'sparkle_formation', '>= 0.2.8'
  s.executables << 'sfn'
  s.files = Dir['{lib,bin}/**/*'] + %w(sfn.gemspec README.md CHANGELOG.md LICENSE)
end
