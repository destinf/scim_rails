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

  describe "create" do
    let(:company) { create(:company) }

    context "when unauthorized" do
      it "returns scim+json content type" do
        post :create, as: :json

        expect(response.media_type).to eq "application/scim+json"
      end

      it "fails with no credentials" do
        post :create, as: :json

        expect(response.status).to eq 401
      end

      it "fails with invalid credentials" do
        request.env['HTTP_AUTHORIZATION'] = ActionController::HttpAuthentication::Basic.encode_credentials("unauthorized","123456")

        post :create, as: :json

        expect(response.status).to eq 401
      end
    end

    context "when authorized" do
      before :each do
        http_login(company)
      end

      it "returns scim+json content type" do
        post :create, params: {
          displayName: "NewGroup"
        }, as: :json

        expect(response.media_type).to eq "application/scim+json"
      end

      it "is successful with valid credentials" do
        expect(company.groups.count).to eq 0

        post :create, params: {
          displayName: "NewGroup",
        }, as: :json

        expect(response.status).to eq 201
        expect(company.groups.count).to eq 1
        group = company.groups.first
        expect(group.persisted?).to eq true
        expect(group.name).to eq "NewGroup"
      end

      it "ignores unconfigured params" do
        post :create, params: {
          displayName: "NewGroup",
          rank: "Jedi"
        }, as: :json

        expect(response.status).to eq 201
        expect(company.groups.count).to eq 1
      end

      # it "returns 422 if required params are missing" do
      #   post :create, params: {
      #     dummy: :foo
      #   }, as: :json

      #   expect(response.status).to eq 422
      #   expect(company.groups.count).to eq 0
      # end

      it "returns 201 if user already exists and updates user" do
        create(:group, name: "NotNewGroup", company: company)

        post :create, params: {
          displayName: "NotNewGroup",
        }, as: :json

        expect(response.status).to eq 201
        expect(company.groups.count).to eq 1
        expect(company.groups.first.name).to eq "NotNewGroup"
      end

      it "returns 409 if user already exists and config.scim_user_prevent_update_on_create is set to true" do
        allow(ScimRails.config).to receive(:scim_user_prevent_update_on_create).and_return(true)
        create(:group, name: "NotNewGroup", company: company)

        post :create, params: {
          displayName: "NotNewGroup",
        }, as: :json

        expect(response.status).to eq 409
        expect(company.groups.count).to eq 1
      end

      it "creates and archives inactive user" do
        post :create, params: {
          displayName: "NotNewGroup",
          active: "false"
        }, as: :json

        expect(response.status).to eq 201
        expect(company.groups.count).to eq 1
        group = company.groups.first
        expect(group.archived?).to eq true
      end
    end
  end

  describe '#update' do
    let(:company) { create(:company) }
    let(:group) { create(:group, company: company)}

    before :each do
      http_login(company)
    end

    context 'when updating a specific group name' do
      let(:replace_request_params) do
        {
          id: group.id,
          Operations: [{
            op: 'replace',
            value: {
              displayName: 'New Group Name'
            }
          }]
      
        }
      end

      it 'successfully replaces the name' do
        patch :update, params: replace_request_params, as: :json
        expect(response).to have_http_status(:ok)
        expect(group.reload.name).to eq('New Group Name')
      end

      context 'when a group name already exists' do
        let(:group2) { create(:group, company: company, name: 'group2name') }
      
        it 'fails to change the group name' do
          params = {
            id: group2.id,
            Operations: [{
              op: 'replace',
              value: {
                displayName: group.name
              }
            }]
          }
          patch :update, params: params, as: :json
          expect(response).to have_http_status(:conflict)
          expect(group2.reload.name).to eq('group2name')
        end
      end
    end

    context 'when updating specific group membership' do
      let(:params) do
        {
          "schemas": ["urn:ietf:params:scim:api:messages:2.0:PatchOp"],
    "Operations": [{
          "op": "remove",
          "path": "members[value eq \"89bb1940-b905-4575-9e7f-6f887cfb368e\"]"
        },
        {
          "op": "add",
          "path": "members",
          "value": [{
              "value": "23a35c27-23d3-4c03-b4c5-6443c09e7173",
              "display": "test.user@okta.local"
        }]
    }]
        }            
      end

      let(:user) { create(:user, company: company) }
      let(:user2) { create(:user, company: company) }

      it 'can remove members from a group' do
        group.users << user
        expect(group.users.count).to eq(1)

        params = {
          id: group.id,
          schemas: ["urn:ietf:params:scim:api:messages:2.0:PatchOp"],
          Operations: [{
            op: 'remove',
            path: "members[value eq #{user.id}]"
          }]
        }

        patch :update, params: params, as: :json
        expect(group.reload.users.count).to eq(0)
      end

      it 'can add members to a group' do
        params = {
          id: group.id,
          schemas: ["urn:ietf:params:scim:api:messages:2.0:PatchOp"],
          Operations: [{
            op: 'add',
            path: 'members',
            value: [{
              value: user2.id.to_s,
              display: user2.email
            }]
          }]
        }
        expect(group.users.count).to eq(0)
        patch :update, params: params, as: :json
        expect(group.users.count).to eq(1)
      end


      it 'can remove and add members to a group' do
        params = {
          id: group.id,
          schemas: ["urn:ietf:params:scim:api:messages:2.0:PatchOp"],
          Operations: [{
            op: 'remove',
            path: "members[value eq #{user.id}]"
          },
          {
            op: 'add',
            path: 'members',
            value: [{
              value: user2.id.to_s,
              display: user2.email
            }]
          }]
        }
        
        patch :update, params: params, as: :json
        expect(group.users.count).to eq(1)
        expect(group.users).to include(user2)
      end
    end
  end

  describe "delete" do
    let(:company) { create(:company) }
    let(:group) { create(:group, company: company) }

    before :each do
      http_login(company)
    end

    it "deletes a group" do
      delete :destroy, params: { id: group.id }, as: :json
      expect(company.reload.groups.count).to eq(0)
    end

    it "returns an empty response" do
      delete :destroy, params: { id: group.id }, as: :json
      expect(response).to have_http_status(:no_content)
    end

    it "fails if no group exists" do
      expect(company.groups.count).to eq(0)
      delete :destroy, params: { id: 1 }, as: :json
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "put update" do
    let(:company) { create(:company) }

    context "when unauthorized" do
      it "returns scim+json content type" do
        put :put_update, params: { id: 1 }, as: :json

        expect(response.media_type).to eq "application/scim+json"
      end

      it "fails with no credentials" do
        put :put_update, params: { id: 1 }, as: :json

        expect(response.status).to eq 401
      end

      it "fails with invalid credentials" do
        request.env['HTTP_AUTHORIZATION'] = ActionController::HttpAuthentication::Basic.encode_credentials("unauthorized","123456")

        put :put_update, params: { id: 1 }, as: :json

        expect(response.status).to eq 401
      end
    end

    context "when authorized" do
      let!(:group) { create(:group, id: 1, company: company) }

      before :each do
        http_login(company)
      end

      it "returns scim+json content type" do
        put :put_update, params: put_params, as: :json

        expect(response.media_type).to eq "application/scim+json"
      end

      it "is successful with with valid credentials" do
        put :put_update, params: put_params, as: :json
        expect(response.status).to eq 200
      end

      it "deprovisions an active record" do
        request.content_type = "application/scim+json"
        put :put_update, params: put_params(active: false), as: :json

        expect(response.status).to eq 200
        expect(group.reload.active?).to eq false
      end

      it "reprovisions an inactive record" do
        group.archive!
        expect(group.reload.active?).to eq false
        request.content_type = "application/scim+json"
        put :put_update, params: put_params(active: true), as: :json

        expect(response.status).to eq 200
        expect(group.reload.active?).to eq true
      end

      it "returns :not_found for id that cannot be found" do
        get :put_update, params: { id: "fake_id" }, as: :json

        expect(response.status).to eq 404
      end

      it "returns :not_found for a correct id but unauthorized company" do
        new_company = create(:company)
        create(:group, company: new_company, id: 1000)

        get :put_update, params: { id: 1000 }, as: :json

        expect(response.status).to eq 404
      end

      xit "is returns 422 with incomplete request" do
        put :put_update, params: {
          id: 1,
          groupName: "test@example.com",
          emails: [
            {
              value: "test@example.com"
            },
          ],
          active: "true"
        }, as: :json

        expect(response.status).to eq 422
      end
    end
  end


  describe "patch update" do
    let(:company) { create(:company) }

    context "when unauthorized" do
      it "returns scim+json content type" do
        patch :patch_update, params: patch_params(id: 1), as: :json

        expect(response.media_type).to eq "application/scim+json"
      end

      it "fails with no credentials" do
        patch :patch_update, params: patch_params(id: 1), as: :json

        expect(response.status).to eq 401
      end

      it "fails with invalid credentials" do
        request.env['HTTP_AUTHORIZATION'] = ActionController::HttpAuthentication::Basic.encode_credentials("unauthorized","123456")

        patch :patch_update, params: patch_params(id: 1), as: :json

        expect(response.status).to eq 401
      end
    end

    context "when authorized" do
      let!(:group) { create(:group, id: 1, company: company) }

      before :each do
        http_login(company)
      end

      it "returns scim+json content type" do
        patch :patch_update, params: patch_params(id: 1), as: :json

        expect(response.media_type).to eq "application/scim+json"
      end

      it "is successful with valid credentials" do
        patch :patch_update, params: patch_params(id: 1), as: :json
        expect(response.status).to eq 200
      end

      it "returns :not_found for id that cannot be found" do
        get :patch_update, params: patch_params(id: "fake_id"), as: :json

        expect(response.status).to eq 404
      end

      it "returns :not_found for a correct id but unauthorized company" do
        new_company = create(:company)
        create(:group, company: new_company, id: 1000)

        get :patch_update, params: patch_params(id: 1000), as: :json

        expect(response.status).to eq 404
      end

      it "successfully archives group" do
        expect(company.groups.count).to eq 1
        group = company.groups.first
        expect(group.archived?).to eq false

        patch :patch_update, params: patch_params(id: 1), as: :json

        expect(response.status).to eq 200
        expect(company.groups.count).to eq 1
        group.reload
        expect(group.archived?).to eq true
      end

      it "successfully restores group" do
        expect(company.groups.count).to eq 1
        group = company.groups.first.tap(&:archive!)
        expect(group.archived?).to eq true

        patch :patch_update, params: patch_params(id: 1,  active: true), as: :json

        expect(response.status).to eq 200
        expect(company.groups.count).to eq 1
        group.reload
        expect(group.archived?).to eq false
      end

      it "is case insensetive for op value" do
        # Note, this is for backward compatibility. op should always
        # be lower case and support for case insensitivity will be removed
        patch :patch_update, params: {
          id: 1,
          Operations: [
            {
              op: "Replace",
              value: {
                active: false
              }
            }
          ]
        }, as: :json

        expect(response.status).to eq 200
      end

      it "throws an error for non status updates" do
        patch :patch_update, params: {
          id: 1,
          Operations: [
            {
              op: "replace",
              value: {
                name: {
                  givenName: "Francis"
                }
              }
            }
          ]
        }, as: :json

        expect(response.status).to eq 422
        response_body = JSON.parse(response.body)
        expect(response_body.dig("schemas", 0)).to eq "urn:ietf:params:scim:api:messages:2.0:Error"
      end

      it "returns 422 when value is not an object" do
        patch :patch_update, params: {
          id: 1,
          Operations: [
            {
              op: "replace",
              path: "displayName",
              value: "Francis"
            }
          ]
        }

        expect(response.status).to eq 422
        response_body = JSON.parse(response.body)
        expect(response_body.dig("schemas", 0)).to eq "urn:ietf:params:scim:api:messages:2.0:Error"
      end

      it "returns 422 when value is missing" do
        patch :patch_update, params: {
          id: 1,
          Operations: [
            {
              op: "replace"
            }
          ]
        }, as: :json

        expect(response.status).to eq 422
        response_body = JSON.parse(response.body)
        expect(response_body.dig("schemas", 0)).to eq "urn:ietf:params:scim:api:messages:2.0:Error"
      end

      it "returns 422 operations key is missing" do
        patch :patch_update, params: {
          id: 1,
          Foobars: [
            {
              op: "replace"
            }
          ]
        }, as: :json

        expect(response.status).to eq 422
        response_body = JSON.parse(response.body)
        expect(response_body.dig("schemas", 0)).to eq "urn:ietf:params:scim:api:messages:2.0:Error"
      end
    end
  end

  def patch_params(id:, active: false)
    {
      id: id,
      displayName: "Patch Test Group",
      Operations: [
        {
          op: "replace",
          value: {
            active: active
          }
        }
      ]
    }
  end

  def put_params(active: true)
    {
      id: 1,
      displayName: "Test Group",
      active: active
    }
  end
end