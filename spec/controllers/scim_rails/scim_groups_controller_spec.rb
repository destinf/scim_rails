require "spec_helper"

RSpec.describe ScimRails::ScimGroupsController, type: :controller do
  include AuthHelper

  routes { ScimRails::Engine.routes }

  describe "index" do

    let(:group) { create(:group) }
    let(:company) { create(:company) }
    context "when authorized" do
      before :each do
        http_login(company)
      end

      it 'test' do
        get :index, as: :json
        expect(response.media_type).to eq "application/scim+json"
      end

      it "is successful with valid credentials" do
        get :index, as: :json

        expect(response.status).to eq 200
      end

      it "returns all results" do
        create_list(:group, 10, company: company)

        get :index, as: :json
        response_body = JSON.parse(response.body)
        expect(response_body.dig("schemas", 0)).to eq "urn:ietf:params:scim:api:messages:2.0:ListResponse"
        expect(response_body["totalResults"]).to eq 10
      end

    end
  end
  describe "create"
  describe "show"
  describe "put_update"
  describe "patch_update"
end