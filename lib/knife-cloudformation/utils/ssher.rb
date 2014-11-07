require 'knife-cloudformation'

module KnifeCloudformation
  module Utils

    # Helper methods for SSH interactions
    module Ssher

      # Retrieve file from remote node
      #
      # @param address [String]
      # @param user [String]
      # @param path [String] remote file path
      # @param ssh_opts [Hash]
      # @return [String, NilClass]
      def remote_file_contents(address, user, path, ssh_opts={})
        require 'net/ssh'
        content = ''
        ssh_session = Net::SSH.start(address, user, ssh_opts)
        content = ssh.exec!("sudo cat #{path}")
        content.empty? ? nil : content
      end

    end
  end
end
