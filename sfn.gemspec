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
  s.add_dependency 'miasma', '~> 0.2.20'
  s.add_dependency 'miasma-aws', '~> 0.1.16'
  s.add_dependency 'net-ssh'
  s.add_dependency 'sparkle_formation', '>= 0.4.0', '< 1.0'
  s.executables << 'sfn'
  s.files = Dir['{lib,bin}/**/*'] + %w(sfn.gemspec README.md CHANGELOG.md LICENSE)
  s.post_install_message = <<-EOF

This version of sfn restricts the SparkleFormation library to versions prior to the
1.0 release. That's great for now but it means many features will not be available
and only fixes will be backported and applied to this gem.

It is highly suggested that you upgrade to the 1.0 version of sfn or later to take
advantage of new features and new development. This gem will continue on in
maintenance mode for the near term future. Once EOL has been reached, this message
will be updated.

Thanks and happy stacking!
EOF

end
