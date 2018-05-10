require "sfn"

module Sfn
  class Config
    # Promote command configuration
    class Promote < Config
      attribute(
        :accounts, String,
        :description => "JSON accounts file path",
      )
      attribute(
        :bucket, String,
        :description => "Bucket name containing the exports",
      )
      attribute(
        :bucket_prefix, String,
        :description => "Key prefix within remote bucket",
      )
    end
  end
end
