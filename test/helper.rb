require 'sfn'
require 'bogo-ui'
require 'minitest/autorun'
require 'mocha/mini_test'
require 'tempfile'
require 'openssl'

# Stub out HTTP so we can easily intercept remote calls
require 'http'

module HTTP

  class << self
    HTTP::Request::METHODS.each do |h_method|
      define_method(h_method) do |*args|
        $mock.send(h_method, *args)
      end
    end
  end

  class Client

    HTTP::Request::METHODS.each do |h_method|
      define_method(h_method) do |*args|
        $mock.send(h_method, *args)
      end
    end

  end

end

module SfnHttpMock
  def setup
    $mock = Mocha::Mock.new(Mocha::Mockery.instance)
  end

  def teardown
    $mock = nil
    @ui = nil
    @stream = nil
    if(@google_key && File.exist?(@google_key))
      File.delete(@google_key)
    end
  end

  def stream
    @stream ||= StringIO.new('')
  end

  def ui
    @ui ||= Bogo::Ui.new(
      :app_name => 'TestUi',
      :output_to => stream,
      :colors => false
    )
  end

  def aws_creds
    Smash[
      %w(aws_access_key_id aws_secret_access_key aws_region).map do |key|
        [key, key.upcase]
      end
    ].merge(:provider => :aws)
  end

  def azure_creds
    Smash[
      %w(azure_tenant_id azure_client_id azure_subscription_id azure_client_secret
        azure_region azure_blob_account_name azure_blob_secret_key).map do |key|
        [key, key.upcase]
      end
    ].merge(:provider => :azure)
  end

  def google_creds
    key_file = Tempfile.new('sfn-test')
    key_file.puts OpenSSL::PKey::RSA.new(2048).to_pem
    key_file.close
    @google_key = key_file.path
    Smash[
      %w(google_service_account_email google_auth_scope google_project).map do |key|
        [key, key.upcase]
      end
    ].merge(
      :provider => :google,
      :google_service_account_private_key => @google_key
    )
  end

  def heat_creds
  end

  def rackspace_creds
    Smash[
      %w(rackspace_api_key rackspace_username rackspace_region).map do |key|
        [key, key.upcase]
      end
    ].merge(:provider => :rackspace)
  end

  def http_response(opts={})
    opts[:version] ||= '1.1'
    opts[:status] ||= 200
    opts[:body] ||= ''
    HTTP::Response.new(opts)
  end
end

class MiniTest::Test
  include SfnHttpMock
end
