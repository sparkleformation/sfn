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

    it 'should display tags' do
      instance = Sfn::Command::Describe.new({:ui => ui}.merge(credentials), ['test-stack'])
      instance.execute!
      stream.rewind
      output = stream.read
      output.must_include 'test-tag'
      output.must_include 'test-tag-value'
    end

  end

  describe 'Google' do

    let(:creds){ google_creds }
    let(:google_get_deployments) do
      Smash.new(
        :deployments => [
          Smash.new(
            :id => '11111',
            :insertTime => Time.now.xmlschema,
            :selfLink => 'http://example.com',
            :name => 'test-stack',
            :operation => {
              :id => '222222',
              :name => 'test-stack-operation',
              :operationType => 'update',
              :status => 'DONE',
              :progress => 100,
              :startTime => Time.now.xmlschema,
              :endTime => Time.now.xmlschema
            },
            :fingerprint => '9999',
            :manifest => 'http://example.com/test-stack.manifest'
          )
        ]
      )
    end
    let(:google_get_resources) do
      Smash.new(
        :resources => [
          {
            :id => '33333',
            :insertTime => Time.now.xmlschema,
            :updateTime => Time.now.xmlschema,
            :name => 'testResource',
            :type => 'custom.v1.resource'
          }
        ]
      )
    end
    let(:google_get_manifest) do
      Smash.new(
        :id => '11111',
        :selfLink => 'http://example.com',
        :insertTime => Time.now.xmlschema,
        :name => 'manifest-test-stack',
        :config => {
          :content => {
            'resources' => [{'name' => 'test-resource', 'type' => 'test-type'}]
          }.to_yaml
        },
        :imports => [
          {:name => 'test-file', :content => {'resources' => []}.to_yaml}
        ],
        :expandedConfig => {}.to_yaml,
        :layout => {'outputs' => [{'name' => 'test-output', 'finalValue' => 'test-output-value'}]}.to_yaml
      )
    end
    let(:google_auth_token) do
      Smash.new(
        :access_token => 'TOKEN',
        :token_type => 'TYPE',
        :expires_in => 300
      )
    end

    before do
      $mock.expects(:get).with{|url|
        url.end_with?('deployments')
      }.returns(http_response(:body => google_get_deployments.to_json)).once
      $mock.expects(:get).with{|url|
        url.include?('deployments') && url.include?('test-stack')
      }.returns(http_response(:body => google_get_deployments[:deployments].first.to_json)).at_least_once
      $mock.expects(:get).with{|url|
        url.include?('manifest')
      }.returns(http_response(:body => google_get_manifest.to_json)).at_least_once
      $mock.expects(:post).with{|url, opts|
        url.include?('oauth2')
      }.returns(http_response(:body => google_auth_token.to_json)).once
      $mock.expects(:get).with{|url|
        url.include?('resources')
      }.returns(http_response(:body => google_get_resources.to_json)).once
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
      output.must_include 'testResource'
      output.must_include 'custom.v1.resource'
    end

    it 'should not display tags' do
      instance = Sfn::Command::Describe.new({:ui => ui}.merge(credentials), ['test-stack'])
      instance.execute!
      stream.rewind
      output = stream.read
      output.must_include 'No tags'
    end

  end

end
