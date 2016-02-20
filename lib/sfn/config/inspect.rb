require 'sfn'

module Sfn
  class Config
    # Inspect command configuration
    class Inspect < Config

      attribute(
        :attribute, String,
        :multiple => true,
        :description => 'Dot delimited attribute to view',
        :short_flag => 'a'
      )
      attribute(
        :nodes, [TrueClass, FalseClass],
        :description => 'Locate all instances and display addresses',
        :short_flag => 'n'
      )
      attribute(
        :load_balancers, [TrueClass, FalseClass],
        :description => 'Locate all load balancers, display addresses and server states',
        :short_flag => 'l'
      )
      attribute(
        :instance_failure, [TrueClass, FalseClass],
        :description => 'Display log file error from failed not if possible',
        :short_flag => 'N'
      )
      attribute(
        :failure_log_path, String,
        :description => 'Path to remote log file for display on failure',
        :default => '/var/log/chef/client.log',
        :short_flag => 'f'
      )
      attribute(
        :identity_file, String,
        :description => 'SSH identity file for authentication',
        :short_flag => 'D'
      )
      attribute(
        :ssh_user, String,
        :description => 'SSH username for inspection connect',
        :short_flag => 's'
      )

    end
  end
end
