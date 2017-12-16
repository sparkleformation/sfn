require_relative '../helper'

describe Sfn::Config do
  describe 'Core configuration' do
    it 'should properly coerce string value to hash' do
      config = Sfn::Config.new(:credentials => 'key1:value1,key2:value2')
      config[:credentials].must_equal 'key1' => 'value1', 'key2' => 'value2'
    end
  end
end
