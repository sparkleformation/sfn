require_relative '../helper'

describe Sfn::Planner do

  let(:ui) do
    Bogo::Ui.new(
      :app_name => 'TestUi',
      :output_to => @stream,
      :colors => false
    )
  end
  let(:stream){ StringIO.new('') }
  let(:api) do
    unless(@api)
      @api = mock
    end
    @api
  end
  let(:default_stack_data) do
    Smash.new(
      :id => '_TEST_ID_',
      :name => '_TEST_NAME_'
    )
  end
  let(:stack_data){ Smash.new }
  let(:stack) do
    unless(@stack)
      @stack = Miasma::Models::Orchestration::Stack.new(
        api, default_stack_data.merge(stack_data)
      ).valid_state
      @stack.parameters = {}
    end
    @stack
  end
  let(:config){ Smash.new }
  let(:arguments){ [] }
  let(:options){ Smash.new }
  let(:planner_type){ Sfn::Planner }
  let(:planner) do
    planner_type.new(ui, config, arguments, stack, options)
  end

  it 'should raise error on plan generation' do
    ->{ planner.generate_plan({}, {}) }.must_raise NotImplementedError
  end

  describe Sfn::Planner::Aws do

    let(:stack_data) do
      Smash.new(
        :parameters => {},
        :template => {}
      )
    end
    let(:planner_type){ Sfn::Planner::Aws }

    before do
      api.expects(:aws_region).returns('us-west-2').at_least_once
      api.expects(:stack_reload).at_least_once
    end

    it 'should return empty plan when templates are empty' do
      api.expects(:stack_template_load).returns({}).at_least_once
      result = planner.generate_plan({}, {})
      result.delete(:stacks).values.map(&:values).flatten.all?(&:empty?).must_equal true
      result.values.all?(&:empty?).must_equal true
    end

    describe 'Resource modification' do

      before do
        api.expects(:data).returns({}).at_least_once
      end

      let(:template) do
        Smash.new(
          'Resources' => {
            'Ec2Instance' => {
              'Type' => 'AWS::EC2::Instance',
              'Properties' => {
                'ImageId' => 'ack'
              }
            }
          }
        )
      end

      it 'should return empty plan when templates are empty' do
        api.expects(:stack_template_load).returns(
          {
            'Resources' => {
              'Ec2Instance' => {
                'Type' => 'AWS::EC2::Instance',
                'Properties' => {
                  'ImageId' => 'quack'
                }
              }
            }
          }
        ).at_least_once
        result = planner.generate_plan(template, {})[:stacks][stack.name]
        result[:replace].wont_be :empty?
        result[:replace]['Ec2Instance']['name'].must_equal 'Ec2Instance'
        result[:replace]['Ec2Instance']['type'].must_equal 'AWS::EC2::Instance'
        result[:replace]['Ec2Instance']['properties'].must_include 'ImageId'
      end

    end

    describe 'Resource removal' do

      before do
        api.expects(:data).returns({}).at_least_once
      end

      let(:template) do
        Smash.new(
          'Resources' => {}
        )
      end

      it 'should return empty plan when templates are empty' do
        api.expects(:stack_template_load).returns(
          {
            'Resources' => {
              'Ec2Instance' => {
                'Type' => 'AWS::EC2::Instance',
                'Properties' => {
                  'ImageId' => 'quack'
                }
              }
            }
          }
        ).at_least_once
        result = planner.generate_plan(template, {})[:stacks][stack.name]
        result[:removed].wont_be :empty?
        result[:removed]['Ec2Instance']['name'].must_equal 'Ec2Instance'
        result[:removed]['Ec2Instance']['type'].must_equal 'AWS::EC2::Instance'
      end

    end

    describe 'Resource addition' do

      before do
        api.expects(:data).returns({}).at_least_once
      end

      let(:template) do
        Smash.new(
          'Resources' => {
            'Ec2Instance' => {
              'Type' => 'AWS::EC2::Instance',
              'Properties' => {
                'ImageId' => 'ack'
              }
            }
          }
        )
      end

      it 'should return empty plan when templates are empty' do
        api.expects(:stack_template_load).returns(
          {
            'Resources' => {}
          }
        ).at_least_once
        result = planner.generate_plan(template, {})[:stacks][stack.name]
        result[:added].wont_be :empty?
        result[:added]['Ec2Instance']['name'].must_equal 'Ec2Instance'
        result[:added]['Ec2Instance']['type'].must_equal 'AWS::EC2::Instance'
      end

    end

  end
end
