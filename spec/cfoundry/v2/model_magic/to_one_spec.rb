require "spec_helper"

class AssociatedModel < CFoundry::V2::Model
  attribute :attribute, String
end

module CFoundry
  module V2
    module ModelMagic
      describe ToOne do
        let(:client) { build(:client) }
        let(:model) { model.new("my-object-guid-1", client) }

        describe "to_one relationships" do
          describe "writing" do
            let(:model) do
              TestModelBuilder.build("my-model-guid-1", client) { to_one :associated_model }
            end

            let(:other_model) do
              AssociatedModel.new("my-model-guid-2", client)
            end

            before do
              stub_request(:get, /v2\/test_models\/.*/).to_return(:body => {:entity => {}}.to_json)
            end

            it "sets the GUID in the manifest to the object's GUID" do
              expect {
                model.associated_model = other_model
              }.to change { model.manifest[:entity][:associated_model_guid] }.to(other_model.guid)
            end

            it "tracks internal changes in the diff" do
              expect {
                model.associated_model = other_model
              }.to change { model.diff }.to(:associated_model_guid => other_model.guid)
            end

            it "tracks high-level changes in .changes" do
              previous_associated_model = AssociatedModel.new("my-model-guid-3", client)
              model.associated_model = previous_associated_model

              expect {
                model.associated_model = other_model
              }.to change { model.changes }.to(:associated_model => [previous_associated_model, other_model])
            end

            it "returns the assigned value" do
              expect(model.send(:associated_model=, other_model)).to eq(other_model)
            end

            context "when there is a default" do
              let(:model) { TestModelBuilder.build("my-model-guid-1", client) { to_one :associated_model, :default => nil } }

              before do
                model.associated_model = other_model
              end

              it "allows setting to the default" do
                expect {
                  model.associated_model = nil
                }.to change {
                  model.manifest[:entity][:associated_model_guid]
                }.from(other_model.guid).to(nil)
              end
            end
          end

          describe "associated create" do
            let(:model) do
              TestModelBuilder.build("my-model-guid-1", client) { to_one :associated_model }
            end

            before do
              WebMock.stub_request(:post, /v2\/associated_model/).to_return(:body => {:metadata => {:guid => "thing"}}.to_json)
            end

            it "returns a new associated object" do
              expect(model.create_associated_model).to be_a(AssociatedModel)
            end

            it "sets the relation" do
              created = model.create_associated_model
              expect(model.associated_model).to eq(created)
            end

            context "with attributes for the association" do
              it "sets these attributes on the association" do
                created = model.create_associated_model(:attribute => "value")
                expect(created.attribute).to eq("value")
              end
            end

            context "when creation fails" do
              it "raises an exception" do
                WebMock.stub_request(:post, /v2\/associated/).to_raise(:not_authorized)
                expect { instance.create_associated }.to raise_error(StandardError)
              end
            end
          end
        end
      end
    end
  end
end