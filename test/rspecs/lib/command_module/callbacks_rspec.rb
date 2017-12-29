require_relative '../../../rspecs'

RSpec.describe Sfn::CommandModule::Callbacks do
  let(:ui) { double(:ui) }
  let(:callbacks) { [] }
  let(:config) { double(:config) }
  let(:arguments) { double(:arguments) }
  let(:provider) { double(:provider) }
  let(:instance) { klass.new(config, ui, arguments, provider) }
  let(:klass) {
    Class.new {
      include Sfn::CommandModule::Callbacks
      attr_reader :config, :ui, :arguments, :provider

      def initialize(c, u, a, p)
        @config = c
        @ui = u
        @arguments = a
        @provider = p
      end

      def self.name
        'Sfn::Callback::Status'
      end
    }
  }

  before do
    allow(Sfn::Callback).to receive(:const_get).and_return(klass)
    allow(config).to receive(:fetch).with(:callbacks, any_args).and_return(callbacks)
    allow(ui).to receive(:debug)
    allow(ui).to receive(:info)
    allow(config).to receive(:[])
    allow(ui).to receive(:color)
  end

  describe '#api_action!' do
    before { allow(instance).to receive(:run_callbacks_for) }

    it 'should run specific and general before and after callbacks' do
      expect(instance).to receive(:run_callbacks_for).with(["before_status", :before], any_args)
      expect(instance).to receive(:run_callbacks_for).with(["after_status", :after], any_args)
      instance.api_action!
    end

    it 'should run failed callbacks on error' do
      expect(instance).to receive(:run_callbacks_for).with(["before_status", :before], any_args)
      expect(instance).to receive(:run_callbacks_for).with(["failed_status", :failed], any_args)
      expect { instance.api_action! { raise 'error' } }.to raise_error(RuntimeError)
    end

    it 'should provide exception to callbacks on error' do
      expect(instance).to receive(:run_callbacks_for).with(["failed_status", :failed], instance_of(RuntimeError))
      expect { instance.api_action! { raise 'error' } }.to raise_error(RuntimeError)
    end
  end

  describe '#run_callbacks_for' do
    let(:callbacks) { ['status'] }

    it 'should run the callback' do
      expect_any_instance_of(klass).to receive(:before)
      instance.run_callbacks_for(:before)
    end
  end

  describe '#callbacks_for' do
    it 'should load callbacks defined within configuration' do
      expect(config).to receive(:fetch).with(:callbacks, :before, []).and_return([])
      expect(config).to receive(:fetch).with(:callbacks, :default, []).and_return([])
      expect(instance.callbacks_for(:before)).to eq([])
    end

    context 'callback name configured' do
      let(:callbacks) { ['status'] }

      it 'should lookup callbacks within namespace' do
        expect(Sfn::Callback).to receive(:const_get).with('Status').and_return(klass)
        expect(instance.callbacks_for(:before)).to be_a(Array)
      end

      it 'should raise error when class not found' do
        expect(Sfn::Callback).to receive(:const_get).and_call_original
        expect { instance.callbacks_for(:before) }.to raise_error(NameError)
      end
    end
  end
end
