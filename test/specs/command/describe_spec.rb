require_relative '../../helper'

describe Sfn::Command::Describe do

  let(:creds){ Smash.new }
  let(:credentials){ Smash.new(:credentials => creds) }

  describe 'AWS' do

    let(:creds){ aws_creds }
    let(:aws_describe_stacks) do
      res = Smash.new
      res.set('DescribeStacksResponse', 'DescribeStacksResult', 'Stacks', 'member',
        Smash.new(
          'Outputs' => {
            'member' => [
              Smash.new('OutputKey' => 'test-output', 'OutputValue' => 'test-output-value')
            ]
          },
          'CreationTime' => Time.now.xmlschema,
          'StackName' => 'test-stack',
          'StackId' => 'arn:aws:cloudformation:REGION:ACCT_ID:stack/test-stack/UUID',
          'StackStatus' => 'CREATE_COMPLETE',
          'Tags' => {
            'member' => {
              "Key" => 'test-tag',
              "Value" => 'test-tag-value'
            }
          },
        )
      )
      res
    end
    let(:aws_list_resources) do
      res = Smash.new
      res.set('ListStackResourcesResponse', 'ListStackResourcesResult', 'StackResourceSummaries', 'member', [
        'LastUpdatedTimestamp' => Time.now.xmlschema,
        'PhysicalResourceId' => 'TestStackResourceId',
        'LogicalResourceId' => 'TestStackResource',
        'ResourceStatus' => 'CREATE_COMPLETE',
        'ResourceType' => 'Custom::TestResource'
      ])
      res
    end

    before do
      $mock.expects(:post).with{|url, opts|
        opts.to_smash.get(:form, 'Action') == 'DescribeStacks'
      }.returns(http_response(:body => aws_describe_stacks.to_json)).once
      $mock.expects(:post).with{|url, opts|
        opts.to_smash.get(:form, 'Action') == 'ListStackResources'
      }.returns(http_response(:body => aws_list_resources.to_json)).once
    end

    it 'should display outputs' do
      instance = Sfn::Command::Describe.new({:ui => ui}.merge(credentials), ['test-stack'])
      instance.execute!
      stream.rewind
      output = stream.read
      output.must_include 'Test Output'
      output.must_include 'test-output-value'
    end

    it 'should display resources' do
      instance = Sfn::Command::Describe.new({:ui => ui}.merge(credentials), ['test-stack'])
      instance.execute!
      stream.rewind
      output = stream.read
      output.must_include 'TestStackResource'
      output.must_include 'Custom::TestResource'
    end

  end

end
