require_relative '../../helper'

describe Sfn::Utils::StackParameterValidator do
  let(:validator) do
    klass = Class.new
    klass.include Sfn::Utils::StackParameterValidator
    klass.new
  end

  it 'should detect list types' do
    validator.list_type?('CommaDelimitedString').must_equal true
    validator.list_type?('comma_delimited_string').must_equal true
    validator.list_type?('List<String>').must_equal true
    validator.list_type?('List<AWS::EC2::Image::Id>').must_equal true
  end

  it 'should not detect non-list types' do
    validator.list_type?('Number').must_equal false
    validator.list_type?('json').must_equal false
    validator.list_type?('AWS::EC2::Image::Id').must_equal false
  end

  it 'should reject value under min value' do
    validator.min_value(2, 3).wont_equal true
  end

  it 'should accept value above min value' do
    validator.min_value(4, 3).must_equal true
  end

  it 'should accept value equal to min value' do
    validator.min_value(3, 3).must_equal true
  end

  it 'should reject value over max value' do
    validator.max_value(4, 3).wont_equal true
  end

  it 'should accept value below max value' do
    validator.max_value(3, 4).must_equal true
  end

  it 'should accept value equal to max value' do
    validator.max_value(3, 3).must_equal true
  end

  it 'should reject value under min length' do
    validator.min_length('fubar', 6).wont_equal true
  end

  it 'should accept value over min length' do
    validator.min_length('fubar', 4).must_equal true
  end

  it 'should accept value equal to min length' do
    validator.min_length('fubar', 5).must_equal true
  end

  it 'should reject value over max length' do
    validator.max_length('fubar', 4).wont_equal true
  end

  it 'should accept value under max length' do
    validator.max_length('fubar', 6).must_equal true
  end

  it 'should accept value equal to max length' do
    validator.max_length('fubar', 5).must_equal true
  end

  it 'should reject value not matching pattern' do
    validator.allowed_pattern('invalid-ami-9999', '^ami-\d+$').wont_equal true
  end

  it 'should accept value matching pattern' do
    validator.allowed_pattern('ami-9999', '^ami-\d+$').must_equal true
  end

  it 'should reject value not defined within allowed values' do
    validator.allowed_values('ack', ['valid1', 'valid2']).wont_equal true
  end

  it 'should accept value defined within allowed values' do
    validator.allowed_values('ack', ['valid1', 'ack', 'valid2']).must_equal true
  end

  describe 'Definition validation' do
    it 'should reject value as too long' do
      result = validator.validate_parameter('fubar',
                                            'MaxLength' => 4)
      result.wont_equal true
      result.size.must_equal 1
      result = result.first
      result.first.must_equal 'max_length'
      result.last.must_be_kind_of String
    end

    it 'should process multiple values when list' do
      result = validator.validate_parameter('fubar,ack',
                                            'Type' => 'CommaDelimitedList',
                                            'MaxLength' => 4)
      result.wont_equal true
      result.size.must_equal 1
      result = result.first
      result.first.must_equal 'max_length'
      result.last.must_be_kind_of String
    end

    it 'should process multiple values when list and reject all' do
      results = validator.validate_parameter('fubar,ack',
                                             'Type' => 'CommaDelimitedList',
                                             'MaxLength' => 2)
      results.wont_equal true
      results.size.must_equal 2
      results.each do |result|
        result.first.must_equal 'max_length'
        result.last.must_be_kind_of String
      end
    end

    it 'should process CFN List type' do
      results = validator.validate_parameter('fubar,ack',
                                             'Type' => 'List<String>',
                                             'MaxLength' => 2)
      results.wont_equal true
      results.size.must_equal 2
      results.each do |result|
        result.first.must_equal 'max_length'
        result.last.must_be_kind_of String
      end
    end

    it 'should process HOT list type' do
      results = validator.validate_parameter('fubar,ack',
                                             'type' => 'comma_delimited_string',
                                             'max_length' => 2)
      results.wont_equal true
      results.size.must_equal 2
      results.each do |result|
        result.first.must_equal 'max_length'
        result.last.must_be_kind_of String
      end
    end
  end
end
