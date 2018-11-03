require "sfn"

module Sfn
  class Config
    # Realize command configuration
    class Realize < Config
      attribute(
        :plan_name, String,
        :description => "Custom plan name or ID",
      )
    end
  end
end
