require_relative '../../helper'
require 'http'

describe Sfn::Command::Create do

  describe 'Default behavior' do

    before do
      $mock.expects(:post).returns(http_response(:body => '[]'))
    end

    it 'should display outputs' do
      instance = Sfn::Command::Create.new(
        Smash.new(
          :ui => ui,
          :file => 'dummy',
          :base_directory => File.join(File.dirname(__FILE__), 'sparkleformation'),
          :poll => false,
          :credentials => {
            :provider => :aws,
            :aws_access_key_id => 'AWS_ID',
            :aws_secret_access_key => 'AWS_KEY',
            :aws_region => 'AWS_REGION'
          }
        ), ['test-stack']
      )
      instance.execute!
      stream.rewind
      output = stream.read
      output.must_include 'creation initialized for test-stack'
    end


  end

end
