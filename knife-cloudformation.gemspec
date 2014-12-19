$LOAD_PATH.unshift File.expand_path(File.dirname(__FILE__)) + '/lib/'
require 'knife-cloudformation/version'
Gem::Specification.new do |s|
  s.name = 'knife-cloudformation'
  s.version = KnifeCloudformation::VERSION.version
  s.summary = 'Knife tooling for Cloud Formation'
  s.author = 'Chris Roberts'
  s.email = 'code@chrisroberts.org'
  s.homepage = 'http://github.com/hw-labs/knife-cloudformation'
  s.description = 'Knife tooling for Cloud Formation'
  s.license = 'Apache-2.0'
  s.require_path = 'lib'
  s.add_dependency 'chef'
  s.add_dependency 'miasma'
  s.add_dependency 'net-ssh'
  s.add_dependency 'sparkle_formation', '~> 0.2.0'
  s.files = Dir['lib/**/*'] + %w(knife-cloudformation.gemspec README.md CHANGELOG.md LICENSE)
end
