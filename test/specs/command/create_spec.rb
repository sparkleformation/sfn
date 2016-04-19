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

      it 'should remove stack property from template when using nested stack' do
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

    let(:azure_container_result) do
      Smash.new(
        'EnumerationResults' => {
          'Containers' => {
            'Container' => [
              Smash.new(
                'Name' => 'miasma-orchestration-templates',
                'Properties' => {
                  'Last_Modified' => Time.now.rfc2822,
                  'Etag' => '"0000"',
                  'LeaseStatus' => 'unlocked',
                  'LeaseState' => 'available'
                }
              )
            ]
          }
        }
      )
    end

    let(:azure_create_resource_group) do
      Smash.new(
        :id => '/resource-group-id/test-stack',
        :name => 'test-stack',
        :location => 'AZURE_REGION',
        :tags => {
          :created => Time.now.to_i,
          :state => 'create'
        },
        :properties => {
          :provisioningState => 'Succeeded'
        }
      )
    end

    let(:azure_create_deployment) do
      Smash.new(
        :id => '/deployment-id/miasma-stack',
        :name => 'miasma-stack',
        :properties => {
          :mode => 'Complete',
          :provisioningState => 'Accepted',
          :timestamp => Time.now.xmlschema
        }
      )
    end

    let(:azure_client_access_token) do
      Smash.new(
        :expires_on => Time.now.to_i + 900,
        :not_before => Time.now.to_i - 900,
        :access_token => 'AZURE_TOKEN'
      )
    end

    before do
      $mock.expects(:post).with{|url|
        url.include?('oauth2')
      }.returns(http_response(:body => azure_client_access_token.to_json)).once
      $mock.expects(:get).with{|url, opts={}|
        url.include?('blob') && opts.fetch(:params, {})['comp'] == 'list'
      }.returns(http_response(:body => azure_container_result.to_json))
      $mock.expects(:put).with{|url|
        url.include?('blob')
      }.returns(http_response(:status => 201))
      $mock.expects(:head).with{|url|
        url.include?('blob')
      }.returns(http_response)
      $mock.expects(:put).with{|url|
        url.end_with?('resourcegroups/test-stack')
      }.returns(http_response(:body => azure_create_resource_group.to_json))
      $mock.expects(:put).with{|url|
        url.end_with?('deployments/miasma-stack')
      }.returns(http_response(:body => azure_create_deployment.to_json))
    end

    describe 'default behavior' do

      it 'should display create initialize' do
        instance = Sfn::Command::Create.new(
          Smash.new(
            :ui => ui,
            :file => 'dummy_azure',
            :base_directory => File.join(File.dirname(__FILE__), 'sparkleformation'),
            :poll => false,
            :credentials => azure_creds
          ), ['test-stack']
        )
        instance.execute!
        stream.rewind
        output = stream.read
        output.must_include 'creation initialized for test-stack'
      end

    end

    describe 'nesting behavior' do

      it 'should display human error when no bucket provided' do
        instance = Sfn::Command::Create.new(
          Smash.new(
            :ui => ui,
            :file => 'nested_dummy_azure',
            :base_directory => File.join(File.dirname(__FILE__), 'sparkleformation'),
            :poll => false,
            :credentials => azure_creds
          ), ['test-stack']
        )
        ->{ instance.execute! }.must_raise StandardError
        stream.rewind
        output = stream.read
        output.must_include 'Missing required configuration value'
        output.must_include 'nesting_bucket'
      end

      it 'should store nested template in bucket' do
        $mock.expects(:put).with{|url, opts|
          if(url.end_with?('test-stack_dummyAzure.json'))
            opts[:body].must_equal({'value' => true}.to_json)
            true
          end
        }.returns(http_response(:status => 201))
        $mock.expects(:head).with{|url, opts|
          url.end_with?('test-stack_dummyAzure.json')
        }.returns(http_response)
        $mock.expects(:put).with{|url, opts|
          if(url.include?('blob') && url.include?('test-stack-') && url.include?('.json'))
            MultiJson.load(opts[:body]).to_smash.fetch(:resources, [{}]).first.get(:properties, :stack).must_equal nil
            true
          end
        }.returns(http_response(:status => 201))
        instance = Sfn::Command::Create.new(
          Smash.new(
            :ui => ui,
            :file => 'nested_dummy_azure',
            :base_directory => File.join(File.dirname(__FILE__), 'sparkleformation'),
            :poll => false,
            :nesting_bucket => 'miasma-orchestration-templates',
            :credentials => azure_creds
          ), ['test-stack']
        )
        instance.execute!
        stream.rewind
        output = stream.read
        output.must_include 'creation initialized for test-stack'
      end

      it 'should remove stack property from template when using nested stack' do
        $mock.expects(:put).with{|url, opts|
          if(url.end_with?('test-stack_dummyAzure.json'))
            true
          end
        }.returns(http_response(:status => 201))
        $mock.expects(:head).with{|url, opts|
          url.end_with?('test-stack_dummyAzure.json')
        }.returns(http_response)
        $mock.expects(:put).with{|url, opts|
          if(url.include?('blob') && url.include?('test-stack-') && url.include?('.json'))
            MultiJson.load(opts[:body]).to_smash.fetch(:resources, [{}]).first.get(:properties, :stack).must_equal nil
            true
          end
        }.returns(http_response(:status => 201))
        instance = Sfn::Command::Create.new(
          Smash.new(
            :ui => ui,
            :file => 'nested_dummy_azure',
            :base_directory => File.join(File.dirname(__FILE__), 'sparkleformation'),
            :poll => false,
            :nesting_bucket => 'miasma-orchestration-templates',
            :credentials => azure_creds
          ), ['test-stack']
        )
        instance.execute!
      end

    end

  end

  describe 'Google' do

    let(:google_auth_token) do
      Smash.new(
        :access_token => 'TOKEN',
        :token_type => 'TYPE',
        :expires_in => 300
      )
    end

    let(:google_create_deployment) do
      Smash.new(
        :kind => 'deploymentmanager#operation',
        :id => 'operation-id',
        :name => 'deployment-operation',
        :operationType => 'insert',
        :targetLink => 'http://example.com/deployments/test-stack',
        :status => 'PENDING',
        :progress => 0,
        :startTime => Time.now.xmlschema
      )
    end

    let(:google_get_deployment) do
      Smash.new(
        :id => 'test-stack-id',
        :name => 'test-stack',
        :insertTime => Time.now.xmlschema,
        :operation => {
          :id => 'operation-id',
          :operationType => 'insert',
          :status => 'RUNNING',
          :progress => 0,
          :startTime => Time.now.xmlschema
        },
        :fingerprint => 'FINGERPRINT-ID',
        :update => {
          :manifest => 'http://example.com/manifests/test-stack.manifest'
        }
      )
    end

    let(:google_get_manifest) do
      Smash.new
    end

    before do
      $mock.expects(:post).with{|url, opts|
        url.include?('oauth2')
      }.returns(http_response(:body => google_auth_token.to_json)).once
      $mock.expects(:get).with{|url|
        url.end_with?('/deployments/test-stack')
      }.returns(http_response(:body => google_get_deployment.to_json))
      $mock.expects(:get).with{|url|
        url.end_with?('/manifests/test-stack.manifest/')
      }.returns(http_response(:body => google_get_manifest.to_json))
    end

    describe 'default behavior' do

      it 'should display create initialize' do
        $mock.expects(:post).with{|url, opts|
          url.end_with?('/deployments') &&
            opts[:json]['name'] == 'test-stack'
        }.returns(http_response(:body => google_create_deployment.to_json))
        instance = Sfn::Command::Create.new(
          Smash.new(
            :ui => ui,
            :file => 'dummy_google',
            :base_directory => File.join(File.dirname(__FILE__), 'sparkleformation'),
            :poll => false,
            :credentials => google_creds
          ), ['test-stack']
        )
        instance.execute!
        stream.rewind
        output = stream.read
        output.must_include 'creation initialized for test-stack'
      end

    end

    describe 'nesting behavior' do

      it 'should remove stack property from template when using nested stack' do
        $mock.expects(:post).with{|url, opts|
          if(url.end_with?('/deployments') && opts[:json]['name'] == 'test-stack')
            import = opts[:json]['target']['imports'].detect do |i|
              i['name'] == 'test-stack.jinja'
            end
            template = YAML.load(import['content'])
            template['resources'].first.fetch(:properties, {}).keys.wont_include 'stack'
            true
          end
        }.returns(http_response(:body => google_create_deployment.to_json))
        instance = Sfn::Command::Create.new(
          Smash.new(
            :ui => ui,
            :file => 'nested_dummy_google',
            :base_directory => File.join(File.dirname(__FILE__), 'sparkleformation'),
            :poll => false,
            :credentials => google_creds
          ), ['test-stack']
        )
        instance.execute!
      end
    end

  end

end
