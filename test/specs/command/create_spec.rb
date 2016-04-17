require_relative '../../helper'
require 'http'

describe Sfn::Command::Create do

  describe 'AWS' do

    describe 'default behavior' do

      before do
        $mock.expects(:post).returns(http_response(:body => '[]'))
      end

      it 'should display create initialize' do
        instance = Sfn::Command::Create.new(
          Smash.new(
            :ui => ui,
            :file => 'dummy',
            :base_directory => File.join(File.dirname(__FILE__), 'sparkleformation'),
            :poll => false,
            :credentials => aws_creds
          ), ['test-stack']
        )
        instance.execute!
        stream.rewind
        output = stream.read
        output.must_include 'creation initialized for test-stack'
      end

    end

    describe 'nesting behavior' do

      before do
        $mock.expects(:head).with{|url|
          url.include?('s3') && url.include?('bucket')
        }.returns(http_response)
      end

      it 'should display human error when no bucket provided' do
        instance = Sfn::Command::Create.new(
          Smash.new(
            :ui => ui,
            :file => 'nested_dummy',
            :base_directory => File.join(File.dirname(__FILE__), 'sparkleformation'),
            :poll => false,
            :credentials => aws_creds
          ), ['test-stack']
        )
        ->{ instance.execute! }.must_raise StandardError
        stream.rewind
        output = stream.read
        output.must_include 'Missing required configuration value'
        output.must_include 'nesting_bucket'
      end

      it 'should store nested template in bucket' do
        $mock.expects(:post).returns(http_response(:body => '[]'))
        $mock.expects(:put).with{|url, opts|
          opts[:body].must_equal({'Value' => true}.to_json)
          url.include?('s3') && url.end_with?('.json')
        }.returns(http_response)
        $mock.expects(:get).with{|url, opts|
          url.include?('s3') && url.end_with?('.json')
        }.returns(http_response)
        instance = Sfn::Command::Create.new(
          Smash.new(
            :ui => ui,
            :file => 'nested_dummy',
            :base_directory => File.join(File.dirname(__FILE__), 'sparkleformation'),
            :poll => false,
            :nesting_bucket => 'bucket',
            :credentials => aws_creds
          ), ['test-stack']
        )
        instance.execute!
        stream.rewind
        output = stream.read
        output.must_include 'creation initialized for test-stack'
      end

      it 'should store nested template in bucket' do
        $mock.expects(:put).with{|url, opts|
          opts[:body].must_equal({'Value' => true}.to_json)
          url.include?('s3') && url.end_with?('.json')
        }.returns(http_response)
        $mock.expects(:get).with{|url, opts|
          url.include?('s3') && url.end_with?('.json')
        }.returns(http_response)
        $mock.expects(:post).with{|url, opts|
          MultiJson.load(opts.to_smash.get(:form, 'TemplateBody')).to_smash.get(
            'Resources', 'Dummy', 'Properties', 'Stack'
          ).must_equal nil
          opts.to_smash.get(:form, 'Action') == 'CreateStack'
        }.returns(http_response(:body => '[]'))
        instance = Sfn::Command::Create.new(
          Smash.new(
            :ui => ui,
            :file => 'nested_dummy',
            :base_directory => File.join(File.dirname(__FILE__), 'sparkleformation'),
            :poll => false,
            :nesting_bucket => 'bucket',
            :credentials => aws_creds
          ), ['test-stack']
        )
        instance.execute!
      end

    end

  end

  describe 'Azure' do
  end

  describe 'Google' do
  end

end
