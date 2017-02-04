require_relative '../../../rspecs'

RSpec.describe Sfn::Callback::StackPolicy do

  let(:ui){ double(:ui) }
  let(:config){ double(:config) }
  let(:arguments){ double(:arguments) }
  let(:api){ double(:api) }

  let(:instance){ subject.new(ui, config, arguments, api) }

  context 'with no stack polciies defined' do
    before do
    end
    it 'should not error if no policies are defined' do

    end
  end

  it 'should fail' do
    expect(true).to be false
  end

end
