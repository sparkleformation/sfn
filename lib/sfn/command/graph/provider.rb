require "sfn"

module Sfn
  class Command
    # Graph command
    class Graph < Command
      module Provider
        autoload :Aws, "sfn/command/graph/aws"
        autoload :Terraform, "sfn/command/graph/terraform"
      end
    end
  end
end
