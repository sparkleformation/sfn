require_relative '../../helper'

describe Sfn::Command::Describe do

  let(:stream){ @stream ||= StringIO.new('') }
  let(:connection){ @connection ||= mock }
  let(:ui) do
    @ui ||= Bogo::Ui.new(
      :app_name => 'TestUi',
      :output_to => stream,
      :colors => false
    )
  end

  let(:stack_collection){ Miasma::Models::Orchestration::Stacks.new(connection) }
  let(:stack_collection_instances){ [stack_model] }
  let(:resource_collection){ Miasma::Models::Orchestration::Stack::Resources.new(connection) }
  let(:resource_collection_instances){ [resource_model] }

  let(:resource_model) do
    Miasma::Models::Orchestration::Stack::Resource.new(connection).load_data(
      :name => 'test-resource',
      :logical_id => 'test-resource',
      :type => 'Test::Resource',
      :state => :create_complete,
      :status => 'Create Complete'
    ).valid_state
  end
  let(:stack_model) do
    Miasma::Models::Orchestration::Stack.new(connection).load_data(
      :id => 'test-stack',
      :name => 'test-stack',
      :template => {},
      :outputs => [Smash.new(:key => 'testing', :value => '123')]
    ).valid_state
  end

  describe 'Default behavior' do

    before do
      connection.expects(:api).returns(connection).at_least_once
      connection.expects(:stack_all).returns(stack_collection_instances).at_least_once
      connection.expects(:class).returns(Miasma::Models::Orchestration::Aws).at_least_once
      connection.expects(:data).returns(Smash.new).at_least_once
      connection.expects(:stacks).returns(stack_collection).at_least_once
      connection.expects(:resource_all).returns(resource_collection_instances).at_least_once
      connection.expects(:stack_reload).returns(stack_model).at_least_once
    end

    it 'should display outputs' do
      instance = command_instance(Sfn::Command::Describe, {}, ['test-stack'])
      instance.execute!
      stream.rewind
      output = stream.read
      output.must_include 'Testing'
      output.must_include '123'
    end

    it 'should display resources' do
      instance = command_instance(Sfn::Command::Describe, {}, ['test-stack'])
      instance.execute!
      stream.rewind
      output = stream.read
      output.must_include 'test-resource'
      output.must_include 'Test::Resource'
    end

  end

end
