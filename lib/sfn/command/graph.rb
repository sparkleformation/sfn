require 'sfn'
require 'graph'

module Sfn
  class Command
    # Graph command
    class Graph < Command
      autoload :Provider, 'sfn/command/graph/provider'

      include Sfn::CommandModule::Base
      include Sfn::CommandModule::Template
      include Sfn::CommandModule::Stack

      # Valid graph styles
      GRAPH_STYLES = [
        'creation',
        'dependency',
      ]

      # Generate graph
      def execute!
        config[:print_only] = true
        validate_graph_style!
        file = load_template_file
        provider = Bogo::Utility.camel(file.provider).to_sym
        if Provider.constants.include?(provider)
          graph_const = Provider.const_get(provider)
          ui.debug "Loading provider graph implementation - #{graph_const}"
          extend graph_const
          @outputs = Smash.new
          ui.info "Template resource graph generation - Style: #{ui.color(config[:graph_style], :bold)}"
          if config[:file]
            ui.puts "  -> path: #{config[:file]}"
          end
          template_dump = file.compile.sparkle_dump!.to_smash
          run_action 'Pre-processing template for graphing' do
            output_discovery(template_dump, @outputs, nil, nil)
            ui.debug 'Output remapping results from pre-processing:'
            @outputs.each_pair do |o_key, o_value|
              ui.debug "#{o_key} -> #{o_value}"
            end
            nil
          end
          graph = nil
          run_action 'Generating resource graph' do
            graph = generate_graph(template_dump)
            nil
          end
          run_action 'Writing graph result' do
            FileUtils.mkdir_p(File.dirname(config[:output_file]))
            if config[:output_type] == 'dot'
              File.open("#{config[:output_file]}.dot", 'w') do |o_file|
                o_file.puts graph.to_s
              end
            else
              graph.save config[:output_file], config[:output_type]
            end
            nil
          end
        else
          valid_providers = Provider.constants.sort.map { |provider|
            Bogo::Utility.snake(provider)
          }.join('`, `')
          ui.error "Graphing for provider `#{file.provider}` not currently supported."
          ui.error "Currently supported providers: `#{valid_providers}`."
        end
      end

      def generate_graph(template, args = {})
        graph = ::Graph.new
        @root_graph = graph unless @root_graph
        graph.graph_attribs << ::Graph::Attribute.new('overlap = false')
        graph.graph_attribs << ::Graph::Attribute.new('splines = true')
        graph.graph_attribs << ::Graph::Attribute.new('pack = true')
        graph.graph_attribs << ::Graph::Attribute.new('start = "random"')
        if args[:name]
          graph.name = "cluster_#{args[:name]}"
          labelnode_key = "cluster_#{args[:name]}"
          graph.plaintext << graph.node(labelnode_key)
          graph.node(labelnode_key).label args[:name]
        else
          graph.name = 'root'
        end
        edge_detection(template, graph, args[:name].to_s.sub('cluster_', ''), args.fetch(:resource_names, []))
        graph
      end

      def colorize(string)
        hash = string.chars.inject(0) do |memo, chr|
          if memo + chr.ord > 127
            (memo - chr.ord).abs
          else
            memo + chr.ord
          end
        end
        color = '#'
        3.times do |i|
          color << (255 ^ hash).to_s(16)
          new_val = hash + (hash * (1 / (i + 1.to_f))).to_i
          if hash * (i + 1) < 127
            hash = new_val
          else
            hash = hash / (i + 1)
          end
        end
        color
      end

      def validate_graph_style!
        if config[:luckymike]
          ui.warn 'Detected luckymike power override. Forcing `dependency` style!'
          config[:graph_style] = 'dependency'
        end
        config[:graph_style] = config[:graph_style].to_s
        unless GRAPH_STYLES.include?(config[:graph_style])
          raise ArgumentError.new "Invalid graph style provided `#{config[:graph_style]}`. Valid: `#{GRAPH_STYLES.join('`, `')}`"
        end
      end
    end
  end
end
