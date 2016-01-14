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
  s.add_dependency 'bogo-cli', '~> 0.1.21'
  s.add_dependency 'miasma', '~> 0.2.27'
  s.add_dependency 'miasma-aws', '~> 0.2.0'
  s.add_dependency 'net-ssh'
  s.add_dependency 'sparkle_formation', '~> 1.1'
  s.add_dependency 'hashdiff', '~> 0.2.2'
  s.add_development_dependency 'rake'
  s.add_development_dependency 'minitest'
  s.add_development_dependency 'mocha'
  s.executables << 'sfn'
  s.files = Dir['{lib,bin,docs}/**/*'] + %w(sfn.gemspec README.md CHANGELOG.md LICENSE)
  s.post_install_message = <<-EOF

This is an install of the sfn gem from the 1.0 release tree. If you
are upgrading from a pre-1.0 version, please review the CHANGELOG and
test your environment _before_ continuing on!

* https://github.com/sparkleformation/sfn/blob/master/CHANGELOG.md

Happy stacking!

EOF

end
