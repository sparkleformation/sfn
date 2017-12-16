require 'sfn'

module Sfn
  class Config

    # Export command configuration
    class Export < Config
      attribute(
        :name, String,
        :description => 'Export file base name',
      )
      attribute(
        :path, String,
        :description => 'Local path prefix for dump file',
      )
      attribute(
        :bucket, String,
        :description => 'Remote storage bucket',
      )
      attribute(
        :bucket_prefix, String,
        :description => 'Remote key prefix within bucket for dump file',
      )
    end
  end
end
