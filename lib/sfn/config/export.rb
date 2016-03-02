require 'sfn'

module Sfn
  class Config

    # Export command configuration
    class Export < Config

      attribute(
        :file_name, String,
        :description => 'Export file base name',
        :short_flag => 'f'
      )
      attribute(
        :directory_path, String,
        :description => 'Local path prefix for dump file',
        :short_flag => 'P'
      )
      attribute(
        :bucket, String,
        :description => 'Remote storage bucket',
        :short_flag => 'b'
      )
      attribute(
        :bucket_prefix, String,
        :description => 'Remote key prefix within bucket for dump file',
        :short_flag => 'B'
      )

    end

  end
end
