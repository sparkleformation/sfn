require 'sfn'

module Sfn
  class Config
    # Inspect command configuration
    class Inspect < Config

      attribute(
        :attribute, String,
        :multiple => true,
        :description => 'Dot delimited attribute to view'
      )
      attribute(
        :nodes, [TrueClass, FalseClass],
        :description => 'Locate all instances and display addresses'
      )
      attribute(
        :instance_failure, String,
        :description => 'Display log file error from failed not if possible',
      )
      attribute(
        :failure_log_path, String,
        :description => 'Path to remote log file for display on failure',
        :default => '/var/log/chef/client.log'
      )
      attribute(
        :identity_file, String,
        :description => 'SSH identity file for authentication'
      )
      attribute(
        :ssh_user, String,
        :description => 'SSH username for inspection connect'
      )

    end
  end
end
