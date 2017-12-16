require_relative '../../helper'

describe Sfn::CommandModule::Stack do
  before do
    @stack = Class.new do
      def initialize
        @config = Smash.new
        @ui = Class.new do
          def debug(*_)
          end
        end.new
      end

      attr_reader :config, :ui
    end
    @stack.include Sfn::CommandModule::Stack
  end

  let(:instance) { @instance ||= @stack.new }

  describe 'Parameter population helpers' do
    describe 'Config parameters location' do
      before do
        instance.config.set(:parameters, :nested__StackItem__MyParameter, 'value')
        instance.config.set(:parameters, :NotNestedParameter, 'value')
        instance.config.set(:parameters, :snake_cased_parameter, 'value')
      end

      it 'should match camel cased parameter' do
        instance.locate_config_parameter_key([], 'NotNestedParameter', 'root').must_equal 'NotNestedParameter'
        instance.config.get(:parameters, 'NotNestedParameter').must_equal 'value'
      end

      it 'should match snake cased parameter when camel cased' do
        instance.locate_config_parameter_key([], 'not_nested_parameter', 'root').must_equal 'not_nested_parameter'
        instance.config.get(:parameters, 'NotNestedParameter').must_be_nil
        instance.config.get(:parameters, :not_nested_parameter).must_equal 'value'
      end

      it 'should match snake cased parameter' do
        instance.locate_config_parameter_key([], 'snake_cased_parameter', 'root').must_equal 'snake_cased_parameter'
        instance.config.get(:parameters, :snake_cased_parameter).must_equal 'value'
      end

      it 'should match camel cased parameter when snake cased' do
        instance.locate_config_parameter_key([], 'SnakeCasedParameter', 'root').must_equal 'SnakeCasedParameter'
        instance.config.get(:parameters, :snake_cased_parameter).must_be_nil
        instance.config.get(:parameters, 'SnakeCasedParameter').must_equal 'value'
      end

      it 'should match camel cased nested stack parameter' do
        instance.locate_config_parameter_key(['nested', 'StackItem'], 'MyParameter', 'root').must_equal 'nested__StackItem__MyParameter'
        instance.config.get(:parameters, 'nested__StackItem__MyParameter').must_equal 'value'
      end

      it 'should match snake cased nested stack parameter when camel cased' do
        instance.locate_config_parameter_key(['nested', 'stack_item'], 'my_parameter', 'root').must_equal 'nested__stack_item__my_parameter'
        instance.config.get(:parameters, 'nested__StackItem__MyParameter').must_be_nil
        instance.config.get(:parameters, 'nested__stack_item__my_parameter').must_equal 'value'
      end

      it 'should return composite key via arg values when not found' do
        instance.locate_config_parameter_key(['nested', 'StackItem'], 'Unknown', 'root').must_equal 'nested__StackItem__Unknown'
      end
    end
  end
end
