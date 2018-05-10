require_relative "../helper"

describe "sfn" do
  def be_sh(command, options = {})
    result = `#{command} 2>&1`
    unless $?.success?
      unless options[:fail] == true || options[:fail] == $?.exitstatus
        raise "Command Failed `#{command}` - #{result}"
      end
    end
    result
  end

  it "shows help without arguments" do
    be_sh("sfn", :fail => true).must_include "Available commands:"
  end

  it "shows help when asking for help" do
    be_sh("sfn --help").must_include "Available commands:"
  end

  it "shows version" do
    be_sh("sfn --version").must_include "SparkleFormation CLI - [Version:"
  end

  it "errors on unknown flags" do
    -> { be_sh("sfn create --fubar") }.must_raise StandardError
    be_sh("sfn create --fubar", :fail => true).must_include "--fubar"
  end

  it "should include stack trace when debug flag provided" do
    be_sh("sfn create --fubar --debug", :fail => true).must_include "in `validate_arguments!"
  end

  describe "configuration file" do
    let(:config_dir) { File.join(File.dirname(__FILE__), "config") }

    it "should load configuration file with no extension" do
      result = Dir.chdir(File.join(config_dir, "no-ext")) do
        be_sh("sfn conf")
      end
      result.must_match /processing.*?:.*?false/
    end

    it "should load Ruby configuration file with extension" do
      result = Dir.chdir(File.join(config_dir, "ruby-ext")) do
        be_sh("sfn conf")
      end
      result.must_match /processing.*?:.*?false/
    end

    it "should load YAML configuration file with extension" do
      result = Dir.chdir(File.join(config_dir, "yaml-ext")) do
        be_sh("sfn conf")
      end
      result.must_match /processing.*?:.*?false/
    end

    it "should load JSON configuration file with extension" do
      result = Dir.chdir(File.join(config_dir, "json-ext")) do
        be_sh("sfn conf")
      end
      result.must_match /processing.*?:.*?false/
    end

    it "should display JSON specific load error when JSON load fails" do
      result = Dir.chdir(File.join(config_dir, "fail-auto-json")) do
        be_sh("sfn conf", :fail => true)
      end
      result.must_include "unexpected token"
    end

    it "should display Ruby specific load error when Ruby load fails" do
      result = Dir.chdir(File.join(config_dir, "fail-auto-ruby")) do
        be_sh("sfn conf", :fail => true)
      end
      result.must_include "syntax error"
    end

    it "should display YAML specific load error when YAML load fails" do
      result = Dir.chdir(File.join(config_dir, "fail-auto-yaml")) do
        be_sh("sfn conf", :fail => true)
      end
      result.must_include "did not find expected node"
    end

    it "should display stacktrace in debug mode on load error" do
      result = Dir.chdir(File.join(config_dir, "fail-auto-yaml")) do
        be_sh("sfn conf --debug", :fail => true)
      end
      result.must_include "Stacktrace"
      result.must_include "SyntaxError"
    end
  end
end
