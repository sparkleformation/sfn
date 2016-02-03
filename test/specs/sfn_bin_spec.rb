require_relative '../helper'

describe 'sfn' do
  def be_sh(command, options={})
    result = `bundle exec #{command} 2>&1`
    unless($?.success?)
      unless(options[:fail] == true || options[:fail] == $?.exitstatus)
        raise "Command Failed `#{command}` - #{result}"
      end
    end
    result
  end

  it 'shows help without arguments' do
    be_sh('sfn', :fail => true).must_include 'Available commands:'
  end

  it 'shows help when asking for help' do
    be_sh('sfn --help').must_include 'Available commands:'
  end

  it 'shows version' do
    be_sh('sfn --version').must_include 'SparkleFormation CLI - [Version:'
  end

  it 'errors on unknown flags' do
    ->{ be_sh('sfn create --fubar') }.must_raise StandardError
    be_sh('sfn create --fubar', :fail => true).must_include '--fubar'
  end

  it 'should include stack trace when debug flag provided' do
    be_sh('sfn create --fubar --debug', :fail => true).must_include 'in `validate_arguments!'
  end


end
