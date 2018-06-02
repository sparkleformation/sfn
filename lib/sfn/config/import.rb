require "sfn"

module Sfn
  class Config

    # Import command configuration
    class Import < Config
      attribute(
        :path, String,
        :description => "Directory path JSON export files are located",
      )
      attribute(
        :bucket, String,
        :description => "Remote storage bucket JSON export files are located",
      )
      attribute(
        :bucket_prefix, String,
        :description => "Remote key prefix within bucket for dump file",
      )
    end
  end
end
