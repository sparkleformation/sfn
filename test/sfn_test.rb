require_relative 'helper'

describe "SFN" do
  def sh(command, options={})
    result = `#{command}`
    raise "FAIL: #{result}" if !!$?.success? == !!options[:fail]
    result
  end

  it "shows help without arguments" do
    sh("./bin/sfn", fail: true).must_include "Available commands:"
  end

  it "shows help when asking for help" do
    sh("./bin/sfn --help").must_include "Available commands:"
  end

  it "shows version" do
    sh("./bin/sfn --version").must_include "SparkleFormation CLI - [Version:"
  end
end
