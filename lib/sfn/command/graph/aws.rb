require 'sfn'

module Sfn
  class Command
    # Graph command
    class Graph < Command
      module Provider
        module Aws
          class AwsGraphProcessor < SparkleFormation::Translation
            MAP = {}
            REF_MAPPING = {}
            FN_MAPPING = {}

            attr_accessor :name

            def initialize(template, args = {})
              super
              @name = args[:name]
            end

            def apply_function(hash, funcs = [])
              k, v = hash.first
              if hash.size == 1
                case k
                when 'Ref'
                  parameters.key?(v) ? parameters[v] : hash
                when 'Fn::Join'
                  v.last
                when 'Fn::Select'
                  v.last[v.first.to_i]
                else
                  hash
                end
              else
                hash
              end
            end
          end

          def output_discovery(template, outputs, resource_name, parent_template, name = '')
            if template['Resources']
              template['Resources'].keys.each do |r_name|
                r_info = template['Resources'][r_name]
                if r_info['Type'] == 'AWS::CloudFormation::Stack'
                  output_discovery(r_info['Properties']['Stack'], outputs, r_name, template, r_name)
                end
              end
            end
            if parent_template
              ui.debug "Pre-processing stack resource `#{resource_name}`"
              substack_parameters = Smash[
                parent_template.fetch('Resources', resource_name, 'Properties', 'Parameters', {}).map do |key, value|
                  result = [key, value]
                  if value.is_a?(Hash)
                    v_key = value.keys.first
                    v_value = value.values.first
                    if v_key == 'Fn::GetAtt' && parent_template.fetch('Resources', {}).keys.include?(v_value.first) && v_value.last.start_with?('Outputs.')
                      output_key = v_value.first + '__' + v_value.last.split('.', 2).last
                      ui.debug "Output key for check: #{output_key}"
                      if outputs.key?(output_key)
                        new_value = outputs[output_key]
                        result = [key, new_value]
                        ui.debug "Parameter for output swap `#{key}`: #{value} -> #{new_value}"
                      end
                    end
                  end
                  result
                end
              ]

              ui.debug "Generated internal parameters for `#{resource_name}`: #{substack_parameters}"

              processor = AwsGraphProcessor.new({},
                                                :parameters => substack_parameters)
              template['Resources'] = processor.dereference_processor(
                template['Resources'], ['Ref']
              )
              template['Outputs'] = processor.dereference_processor(
                template['Outputs'], ['Ref']
              )
              rename_processor = AwsGraphProcessor.new({},
                                                       :parameters => Smash[
                                                         template.fetch('Resources', {}).keys.map do |r_key|
                                                           [r_key, {'Ref' => [name, r_key].join}]
                                                         end
                                                       ])
              derefed_outs = rename_processor.dereference_processor(
                template.fetch('Outputs', {})
              ) || {}

              derefed_outs.each do |o_name, o_data|
                o_key = [name, o_name].join('__')
                outputs[o_key] = o_data['Value']
              end
            end
            outputs.dup.each do |key, value|
              if value.is_a?(Hash)
                v_key = value.keys.first
                v_value = value.values.first
                if v_key == 'Fn::GetAtt' && v_value.last.start_with?('Outputs.')
                  output_key = v_value.first << '__' << v_value.last.split('.', 2).last
                  if outputs.key?(output_key)
                    outputs[key] = outputs[output_key]
                  end
                end
              end
            end
          end

          def edge_detection(template, graph, name = '', resource_names = [])
            resources = template.fetch('Resources', {})
            node_prefix = name
            resources.each do |resource_name, resource_data|
              node_name = [node_prefix, resource_name].join
              if resource_data['Type'] == 'AWS::CloudFormation::Stack'
                graph.subgraph << generate_graph(
                  resource_data['Properties'].delete('Stack'),
                  :name => resource_name,
                  :type => resource_data['Type'],
                  :resource_names => resource_names,
                )
                next
              else
                graph.node(node_name).attributes << graph.fillcolor(colorize(node_prefix.empty? ? config[:file] : node_prefix).inspect)
                graph.box3d << graph.node(node_name)
              end
              graph.filled << graph.node(node_name)
              graph.node(node_name).label "#{resource_name}\n<#{resource_data['Type']}>\n#{name}"
              resource_dependencies(resource_data, resource_names + resources.keys).each do |dep_name|
                if resources.keys.include?(dep_name)
                  dep_name = [node_prefix, dep_name].join
                end
                if config[:graph_style] == 'creation'
                  @root_graph.edge(dep_name, node_name)
                else
                  @root_graph.edge(node_name, dep_name)
                end
              end
            end
            resource_names.concat resources.keys.map { |r_name| [node_prefix, r_name].join }
          end

          def resource_dependencies(data, names)
            case data
            when Hash
              data.map do |key, value|
                if key == 'Ref' && names.include?(value)
                  value
                elsif key == 'DependsOn'
                  [value].flatten.compact.find_all do |dependson_name|
                    names.include?(dependson_name)
                  end
                elsif key == 'Fn::GetAtt' && names.include?(res = [value].flatten.compact.first)
                  res
                else
                  resource_dependencies(key, names) +
                    resource_dependencies(value, names)
                end
              end.flatten.compact.uniq
            when Array
              data.map do |item|
                resource_dependencies(item, names)
              end.flatten.compact.uniq
            else
              []
            end
          end
        end
      end
    end
  end
end
