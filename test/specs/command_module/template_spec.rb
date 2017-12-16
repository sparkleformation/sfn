require_relative '../../helper'

describe Sfn::CommandModule::Template do
  before do
    @template = Class.new do
      def initialize
        @config = Smash.new
        @arguments = []
        @ui = AttributeStruct.new
      end

      attr_reader :config, :arguments, :ui
    end
    @template.include Sfn::CommandModule::Template
  end

  let(:instance) { @instance ||= @template.new }

  describe 'Compile time parameter merging' do
    it 'should automatically merge items when stack name is not used' do
      instance.arguments << 'stack-name'
      instance.config.set(:compile_parameters, 'stack-name__Fubar', 'key1', 'value')
      instance.config.set(:compile_parameters, 'Fubar', 'key2', 'value2')
      result = instance.merge_compile_time_parameters
      result.get('stack-name__Fubar', 'key1').must_equal 'value'
      result.get('stack-name__Fubar', 'key2').must_equal 'value2'
      result.get('Fubar').must_be_nil
    end

    it 'should automatically prefix stack name when not provided' do
      instance.arguments << 'stack-name'
      instance.config.set(:compile_parameters, 'Fubar', 'key2', 'value2')
      result = instance.merge_compile_time_parameters
      result.get('stack-name__Fubar', 'key2').must_equal 'value2'
      result.get('Fubar').must_be_nil
    end
  end
end
