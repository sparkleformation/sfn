require 'sparkle_formation'
require 'sfn'

module Sfn
  class Command
    # Validate command
    class Validate < Command
      include Sfn::CommandModule::Base
      include Sfn::CommandModule::Template
      include Sfn::CommandModule::Stack

      def execute!
        print_only_original = config[:print_only]
        config[:print_only] = true
        file = load_template_file
        ui.info "#{ui.color("Template Validation (#{provider.connection.provider}): ", :bold)} #{config[:file].sub(Dir.pwd, '').sub(%r{^/}, '')}"
        config[:print_only] = print_only_original

        raw_template = _format_json(parameter_scrub!(template_content(file)))

        if config[:print_only]
          ui.puts raw_template
        else
          validate_stack(
            file.respond_to?(:dump) ? file.dump : file,
            if config[:processing]
              sparkle_collection.get(:template, config[:file])[:name]
            else
              config[:file]
            end
          )
        end
      end

      # Validate template with remote API and unpack nested templates if required
      #
      # @param template [Hash] template data structure
      # @param name [String] name of template
      # @return [TrueClass]
      def validate_stack(template, name)
        resources = template.fetch('Resources', {})
        nested_stacks = resources.find_all do |r_name, r_value|
          r_value.is_a?(Hash) &&
            provider.connection.data[:stack_types].include?(r_value['Type'])
        end
        nested_stacks.each do |n_name, n_resource|
          validate_stack(n_resource.fetch('Properties', {}).fetch('Stack', {}), "#{name} > #{n_name}")
          n_resource['Properties'].delete('Stack')
        end
        begin
          ui.info "Validating: #{ui.color(name, :bold)}"
          if config[:upload_root_template]
            upload_result = store_template('validation-stack', template, Smash.new)
            stack = provider.connection.stacks.build(
              :name => 'validation-stack',
              :template_url => upload_result[:url],
            )
          else
            stack = provider.connection.stacks.build(
              :name => 'validation-stack',
              :template => parameter_scrub!(template),
            )
          end
          result = api_action!(:api_stack => stack) do
            stack.validate
          end
          ui.info ui.color('  -> VALID', :bold, :green)
          true
        rescue => e
          ui.info ui.color('  -> INVALID', :bold, :red)
          ui.fatal e.message
          raise e
        end
      end
    end
  end
end
