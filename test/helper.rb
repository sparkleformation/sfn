require 'sfn'
require 'bogo-ui'
require 'minitest/autorun'
require 'mocha/mini_test'

# Stub out HTTP so we can easily intercept remote calls
require 'http'

class HTTP::Client

  HTTP::Request::METHODS.each do |h_method|
    define_method(h_method) do |*args|
      $mock.send(h_method, *args)
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
    Smash.new(
      :provider => :aws,
      :aws_access_key_id => 'AWS_ACCESS_KEY_ID',
      :aws_secret_access_key => 'AWS_SECRET_ACCESS_KEY',
      :aws_region => 'AWS_REGION'
    )
  end

  def http_response(opts)
    opts[:version] ||= '1.1'
    opts[:status] ||= 200
    HTTP::Response.new(opts)
  end
end

class MiniTest::Test
  include SfnHttpMock
end
