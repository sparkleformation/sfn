$LOAD_PATH.unshift File.expand_path(File.dirname(__FILE__)) + '/lib/'
require 'knife-cloudformation/version'
Gem::Specification.new do |s|
  s.name = 'knife-cloudformation'
  s.version = KnifeCloudformation::VERSION.version
  s.summary = 'Knife tooling for Cloud Formation'
  s.author = 'Chris Roberts'
  s.email = 'chrisroberts.code@gmail.com'
  s.homepage = 'http://github.com/heavywater/knife-cloudformation'
  s.description = 'Knife tooling for Cloud Formation'
  s.require_path = 'lib'
  s.add_dependency 'chef'
  s.add_dependency 'fog', '~> 1.17'
  s.add_dependency 'unf'
  s.add_dependency 'net-sftp'
  s.add_dependency 'sparkle_formation', '~> 0.2.0'
  s.add_dependency 'redis-objects'
  s.add_dependency 'attribute_struct', '~> 0.2.0'
  s.files = Dir['**/*']
end
