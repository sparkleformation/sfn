require 'sfn'
require 'bogo-ui'
require 'minitest/autorun'
require 'mocha/mini_test'

def command_instance(klass, config={}, args=[])
  Miasma.test_api = connection
  instance = klass.new(config.merge(:ui => ui, :credentials => {:provider => :aws}), args)
  instance
end

module Miasma
  class << self
    attr_accessor :test_api
    def api(*_)
      test_api
    end
  end
end

require 'miasma/contrib/aws'
