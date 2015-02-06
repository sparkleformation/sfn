require 'sfn'

class Chef
  class Knife

    Sfn::Config.constants.map do |konst|
      const = Sfn::Config.const_get(konst)
      if(const.is_a?(Class) && const.ancestors.include?(Bogo::Config))
        const
      end
    end.compact.sort_by(&:to_s).each do |klass|

      klass_name = klass.name.split('::').last
      command_class = "Cloudformation#{klass_name}"

      shorts = []

      command klass_name do
        if(klass.const_defined?(:DESCRIPTION))
          description klass.const_get(:DESCRIPTION)
        end
        Sfn::Config.attributes.merge(klass.attributes).sort_by(&:first).each do |name, info|
          next unless info[:description]
          short = name.chars.zip(name.chars.map(&:upcase)).flatten.detect do |c|
            !shorts.include?(c)
          end
          shorts << short
          bool = [info[:type]].compact.flatten.all?{|x| BOOLEAN_VALUES.include?(x) }
          on_name = bool ? name.to_s : "#{name}="
          on short, on_name.tr('_', '-'), info[:description], :default => info[:default]
        end

        run do |opts, args|
          klass.new({klass_name => opts}, args)
        end
      end

    end



require 'sparkle_formation'
require 'pathname'
require 'knife-cloudformation'

class Chef
  class Knife
    # Cloudformation create command
    class CloudformationCreate < Knife

      include KnifeCloudformation::Knife::Base
      include KnifeCloudformation::Knife::Template
      include KnifeCloudformation::Knife::Stack

      banner 'knife cloudformation create NAME'

      option(:timeout,
        :short => '-t MIN',
        :long => '--timeout MIN',
        :description => 'Set timeout for stack creation',
