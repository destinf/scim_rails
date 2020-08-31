require "spec_helper"

RSpec.describe ScimRails::ScimGroupsController, type: :controller do
  include AuthHelper

  routes { ScimRails::Engine.routes }

  describe "index" do
    let(:company) { create(:company) }

    context "when unauthorized" do
      it "returns scim+json content type" do
        get :index, as: :json

        expect(response.media_type).to eq "application/scim+json"
      end

      it "fails with no credentials" do
        get :index, as: :json

        expect(response.status).to eq 401
      end

      it "fails with invalid credentials" do
        request.env['HTTP_AUTHORIZATION'] = ActionController::HttpAuthentication::Basic.encode_credentials("unauthorized","123456")

        get :index, as: :json

        expect(response.status).to eq 401
      end
    end

    context "when authorized" do
      before :each do
        http_login(company)
      end

      it "returns scim+json content type" do
        get :index, as: :json

        expect(response.media_type).to eq "application/scim+json"
      end

      it "is successful with valid credentials" do
        get :index, as: :json

        expect(response.status).to eq 200
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

      it "defaults to 100 results" do
        create_list(:group, 300, company: company)

        get :index, as: :json
        response_body = JSON.parse(response.body)
        expect(response_body["totalResults"]).to eq 300
        expect(response_body["Resources"].count).to eq 100
      end

      it "paginates results" do
        create_list(:group, 400, company: company)
        expect(company.groups.first.id).to eq 1

        get :index, params: {
          startIndex: 101,
          count: 200,
        }, as: :json
        response_body = JSON.parse(response.body)
        expect(response_body["totalResults"]).to eq 400
        expect(response_body["Resources"].count).to eq 200
        expect(response_body.dig("Resources", 0, "id")).to eq 101
      end

      it "paginates results by configurable scim_users_list_order" do
        allow(ScimRails.config).to receive(:scim_groups_list_order).and_return({ created_at: :desc })

        create_list(:group, 400, company: company)
        expect(company.groups.first.id).to eq 1

        get :index, params: {
          startIndex: 1,
          count: 10,
        }, as: :json
        response_body = JSON.parse(response.body)
        expect(response_body["totalResults"]).to eq 400
        expect(response_body["Resources"].count).to eq 10
        expect(response_body.dig("Resources", 0, "id")).to eq 400
      end

      it "filters results by provided name filter" do
        create(:group, name: "group1", company: company)
        create(:group, name: "group2", company: company)

        get :index, params: {
          filter: "displayName eq group1"
        }, as: :json
        response_body = JSON.parse(response.body)
        expect(response_body["totalResults"]).to eq 1
        expect(response_body["Resources"].count).to eq 1
      end

      it "returns no results for unfound filter parameters" do
        get :index, params: {
          filter: "displayName eq fake_not_there"
        }, as: :json
        response_body = JSON.parse(response.body)
        expect(response_body["totalResults"]).to eq 0
        expect(response_body["Resources"].count).to eq 0
      end

      it "returns no results for undefined filter queries" do
        get :index, params: {
          filter: "address eq 101 Nowhere USA"
        }, as: :json
        expect(response.status).to eq 400
        response_body = JSON.parse(response.body)
        expect(response_body.dig("schemas", 0)).to eq "urn:ietf:params:scim:api:messages:2.0:Error"
      end
    end
  end

  describe "show" do
    let(:company) { create(:company) }

    context "when unauthorized" do
      it "returns scim+json content type" do
        get :show, params: { id: 1 }, as: :json

        expect(response.media_type).to eq "application/scim+json"
      end

      it "fails with no credentials" do
        get :show, params: { id: 1 }, as: :json

        expect(response.status).to eq 401
      end

      it "fails with invalid credentials" do
        request.env['HTTP_AUTHORIZATION'] = ActionController::HttpAuthentication::Basic.encode_credentials("unauthorized","123456")

        get :show, params: { id: 1 }, as: :json

        expect(response.status).to eq 401
      end
    end

    context "when authorized" do
      before :each do
        http_login(company)
      end

      it "returns scim+json content type" do
        get :show, params: { id: 1 }, as: :json

        expect(response.media_type).to eq "application/scim+json"
      end

      it "is successful with valid credentials" do
        create(:group, id: 1, company: company)
        get :show, params: { id: 1 }, as: :json

        expect(response.status).to eq 200
      end

      it "returns :not_found for id that cannot be found" do
        get :show, params: { id: "fake_id" }, as: :json

        expect(response.status).to eq 404
      end

      it "returns :not_found for a correct id but unauthorized company" do
        new_company = create(:company)
        create(:group, company: new_company, id: 1)

        get :show, params: { id: 1 }, as: :json

        expect(response.status).to eq 404
      end
    end
  end
  describe "create"
  describe "put_update"
  describe "patch_update"
end