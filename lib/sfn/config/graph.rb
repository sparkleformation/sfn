require 'sfn'

module Sfn
  class Config
    # Generate graph
    class Graph < Validate

      attribute(
        :output_file, String,
        :description => 'Directory to write graph files',
        :short_flag => 'O',
        :default => File.join(Dir.pwd, 'sfn-graph')
      )

      attribute(
        :output_type, String,
        :description => 'File output type (Requires graphviz package for non-dot types)',
        :short_flag => 'e',
        :default => 'dot'
      )

    end
  end
end
