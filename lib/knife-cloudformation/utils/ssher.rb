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
        require 'net/sftp'
        content = ''
        ssh_session = Net::SSH.start(address, user, ssh_opts)
        con = Net::SFTP::Session.new(ssh_session)
        con.loop{ con.opening? }
        f_handle = con.open!(path)
        data = ''
        count = 0
        while(data)
          data = nil
          request = con.read(f_handle, count, 1024) do |response|
            unless(response.eof?)
              if(response.ok?)
                count += 1024
                content << response[:data]
                data = true
              end
            end
          end
          request.wait
        end
        con.close!(f_handle)
        con.close_channel
        ssh_session.close
        content.empty? ? nil : content
      end

    end
  end
end
