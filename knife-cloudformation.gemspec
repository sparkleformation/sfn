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
  s.add_dependency 'fog', '~> 1.12.1'
  s.add_dependency 'net-sftp'
  s.add_dependency 'attribute_struct', '~> 0.1.6'
  s.files = Dir['**/*']
end
