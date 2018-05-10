require "sfn"

module Sfn
  class Command
    # Graph command
    class Graph < Command
      module Provider
        module Terraform
          class TerraformGraphProcessor < SparkleFormation::Translation
            MAP = {}
            REF_MAPPING = {}
            FN_MAPPING = {}

            attr_accessor :name

            def initialize(template, args = {})
              super
              @name = args[:name]
            end

            def dereference_processor(obj, funcs = [])
              case obj
              when Array
                obj = obj.map { |v| dereference_processor(v, funcs) }
              when Hash
                new_hash = {}
                obj.each do |k, v|
                  new_hash[k] = dereference_processor(v, funcs)
                end
                obj = new_hash
              when String
                obj = apply_function(obj, funcs)
              end
              obj
            end

            def parameters
              Hash[
                @original.fetch("parameters", {}).map do |k, v|
                  [k, v.fetch("default", "")]
                end
              ].merge(@parameters)
            end

            def resources
              @original.fetch("resources", {})
            end

            def outputs
              @original.fetch("outputs", {})
            end

            def apply_function(string, funcs = [])
              # first check for vars and replace with params
              string.scan(/(\$\{var\.(.+?)\})/).each do |match|
                if parameters[match.last]
                  string.sub!(match.first, parameters[match.last])
                end
              end
              string
            end
          end

          def output_discovery(template, outputs, resource_name, parent_template, name = "")
            if template["resources"]
              template["resources"].keys.each do |r_name|
                r_info = template["resources"][r_name]
                if r_info["type"] == "module"
                  output_discovery(r_info["properties"]["stack"], outputs, r_name, template, r_name)
                end
              end
            end
            if parent_template
              ui.debug "Pre-processing stack resource `#{resource_name}`"
              substack_parameters = Smash[
                parent_template.fetch("resources", resource_name, "properties", "parameters", {}).map do |key, value|
                  result = [key, value]
                  if value.to_s.start_with?("${module.")
                    output_key = value.sub("${module.", "").sub("}", "").sub(".", "__")
                    ui.debug "Output key for check: #{output_key}"
                    if outputs.key?(output_key)
                      new_value = outputs[output_key]
                      result = [key, new_value]
                      ui.debug "Parameter for output swap `#{key}`: #{value} -> #{new_value}"
                    end
                  end
                  result
                end
              ]

              ui.debug "Generated internal parameters for `#{resource_name}`: #{substack_parameters}"

              processor = TerraformGraphProcessor.new({},
                                                      :parameters => substack_parameters)
              template["resources"] = processor.dereference_processor(
                template["resources"], []
              )
              template["outputs"] = processor.dereference_processor(
                template["outputs"], []
              )
              derefed_outs = template["outputs"] || {}
              derefed_outs.each do |o_name, o_data|
                o_key = [name, o_name].join("__")
                val = o_data["value"]
                if val.start_with?("${") && val.scan(".").count == 2
                  val = val.split(".")
                  val[1] = "#{name}__#{val[1]}"
                  val = val.join(".")
                end
                outputs[o_key] = val
              end
            end
            outputs.dup.each do |key, value|
              if value.to_s.start_with?("${module.")
                output_key = value.to_s.sub("${module.", "").sub("}", "").sub(".", "__")
                if outputs.key?(output_key)
                  outputs[key] = outputs[output_key]
                end
              end
            end
          end

          def edge_detection(template, graph, name = "", resource_names = [])
            resources = (template.fetch("resources", {}) || {})
            node_prefix = name
            resources.each do |resource_name, resource_data|
              node_name = [node_prefix, resource_name].join("__")
              if resource_data["type"] == "module"
                graph.subgraph << generate_graph(
                  resource_data["properties"].delete("stack"),
                  :name => resource_name,
                  :type => resource_data["type"],
                  :resource_names => resource_names,
                )
                next
              else
                graph.node(node_name).attributes << graph.fillcolor(colorize(node_prefix.empty? ? config[:file] : node_prefix).inspect)
                graph.box3d << graph.node(node_name)
              end
              graph.filled << graph.node(node_name)
              graph.node(node_name).label "#{resource_name}\n<#{resource_data["type"]}>\n#{name}"
              resource_dependencies(resource_data, resource_names + resources.keys).each do |dep_name|
                if resources.keys.include?(dep_name)
                  dep_name = [node_prefix, dep_name].join("__")
                end
                if config[:graph_style] == "creation"
                  @root_graph.edge(dep_name, node_name)
                else
                  @root_graph.edge(node_name, dep_name)
                end
              end
            end
            resource_names.concat resources.keys.map { |r_name| [node_prefix, r_name].join("__") }
          end

          def resource_dependencies(data, names)
            case data
            when String
              result = []
              if data.start_with?("${") && data.scan(".").count >= 1
                data = data.tr("${}", "")
                check_name = data.split(".")[1]
                if names.include?(check_name)
                  result.push(check_name)
                end
              end
              result
            when Hash
              data.map do |key, value|
                if key == "depends_on"
                  [value].flatten.compact.map do |dependson_name|
                    dep_name = dependson_name.split(".").last
                    dep_name if names.include?(dep_name)
                  end
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
