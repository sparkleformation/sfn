require_relative "../../../rspecs"

RSpec.describe Sfn::CommandModule::Stack::InstanceMethods do
  let(:subject) do
    Class.tap { |c| c.include(described_class) }.new
  end

  describe "#generate_custom_apply_mappings" do
    let(:config) { {apply_mapping: mappings} }
    let(:mappings) { nil }
    let(:provider_stack) { double("provider_stack", api: api, name: stack_name) }
    let(:stack_name) { nil }
    let(:api) { double("api", data: api_data) }
    let(:api_data) { {} }

    before { allow(subject).to receive(:config).and_return(config) }

    it "should return nil by default" do
      expect(subject.generate_custom_apply_mappings(provider_stack)).
        to be_nil
    end

    context "when mappings are set" do
      let(:mappings) {
        {"test-stack__OriginKey" => "DestKey",
         "other-stack__StartKey" => "EndKey"}
      }

      it "should return empty hash" do
        expect(subject.generate_custom_apply_mappings(provider_stack)).
          to eq({})
      end

      context "when stack name is set" do
        let(:stack_name) { "test-stack" }

        it "should return hash with single item" do
          expect(subject.generate_custom_apply_mappings(provider_stack).size).
            to eq(1)
        end

        it "should include the origin key" do
          expect(subject.generate_custom_apply_mappings(provider_stack).keys).
            to include("OriginKey")
        end

        it "should include the dest key value" do
          expect(subject.generate_custom_apply_mappings(provider_stack).values).
            to include("DestKey")
        end
      end

      context "when mappings are plain" do
        let(:mappings) {
          {"OriginKey" => "DestKey",
           "other-stack__StartKey" => "EndKey"}
        }

        it "should return hash with single item" do
          expect(subject.generate_custom_apply_mappings(provider_stack).size).
            to eq(1)
        end

        it "should include the origin key" do
          expect(subject.generate_custom_apply_mappings(provider_stack).keys).
            to include("OriginKey")
        end

        it "should include the dest key value" do
          expect(subject.generate_custom_apply_mappings(provider_stack).values).
            to include("DestKey")
        end
      end

      context "when mapping includes remote location" do
        let(:mappings) {
          {"remote_provider__test-stack__OriginKey" => "DestKey",
           "other-stack__StartKey" => "EndKey"}
        }
        let(:stack_name) { "test-stack" }

        it "should return empty hash" do
          expect(subject.generate_custom_apply_mappings(provider_stack)).
            to eq({})
        end

        context "with location set in api data" do
          let(:api_data) {
            {location: "remote_provider"}
          }

          it "should return hash with single item" do
            expect(subject.generate_custom_apply_mappings(provider_stack).size).
              to eq(1)
          end

          it "should include the origin key" do
            expect(subject.generate_custom_apply_mappings(provider_stack).keys).
              to include("OriginKey")
          end

          it "should include the dest key value" do
            expect(subject.generate_custom_apply_mappings(provider_stack).values).
              to include("DestKey")
          end
        end

        context "when mapping format is invalid" do
          let(:mappings) {
            {"invalid__provider__stack__OriginKey" => "DestKey"}
          }

          it "should raise an error" do
            expect {
              subject.generate_custom_apply_mappings(provider_stack)
            }.to raise_error(ArgumentError)
          end
        end
      end
    end
  end
end
