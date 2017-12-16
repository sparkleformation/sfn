require_relative '../../helper'

describe Sfn::Command::Lint do
  let(:creds) { aws_creds }

  before do
    rs = Sfn::Lint::RuleSet.build(:resource_check) do
      rule :aws_resources_only do
        definition 'Resources.[*][0][*].Type' do |search|
          unless search.nil?
            result = search.find_all { |i| !i.start_with?('AWS') }
            result.empty? ? true : result
          else
            true
          end
        end

        fail_message 'All types must be within AWS root namespace'
      end
    end
    Sfn::Lint::RuleSet.register(rs)
  end

  it 'should successfully run on valid template' do
    instance = Sfn::Command::Lint.new(
      Smash.new(
        :ui => ui,
        :base_directory => File.join(File.dirname(__FILE__), 'sparkleformation'),
        :credentials => aws_creds,
        :file => 'lint_valid',
      ),
      []
    )
    instance.execute!
    stream.rewind
    stream.read.must_include 'VALID'
  end

  it 'should fail on invalid template' do
    instance = Sfn::Command::Lint.new(
      Smash.new(
        :ui => ui,
        :base_directory => File.join(File.dirname(__FILE__), 'sparkleformation'),
        :credentials => aws_creds,
        :file => 'lint_invalid',
      ),
      []
    )
    -> { instance.execute! }.must_raise RuntimeError
    stream.rewind
    stream.read.must_include 'INVALID'
  end
end
