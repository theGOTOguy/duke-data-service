require 'rails_helper'

describe DDS::V1::ProjectAffiliatesAPI do
  let(:json_headers) { { 'Accept' => 'application/json', 'Content-Type' => 'application/json'} }
  let(:user_auth) { FactoryGirl.create(:user_authentication_service, :populated) }
  let(:user) { user_auth.user }
  let (:api_token) { user_auth.api_token }
  let(:json_headers_with_auth) {{'Authorization' => api_token}.merge(json_headers)}

  let(:membership) { FactoryGirl.create(:membership) }
  let(:project) { FactoryGirl.create(:project) }
  let(:serialized_membership) { MembershipSerializer.new(membership).to_json }

  describe 'Create a project affiliate' do
    context 'with valid payload' do
      let(:payload) {{
          user: {
            id: user.uuid
          },
          external_person: nil,
          project_roles: [{id: 'principal_investigator'}]
        }}
      it 'should store a project affiilation with the given payload' do
        expect {
          post "/api/v1/project/#{project.uuid}/affiliates", payload.to_json, json_headers_with_auth
          expect(response.status).to eq(201)
          expect(response.body).to be
          expect(response.body).not_to eq('null')
        }.to change{Membership.count}.by(1)

        response_json = JSON.parse(response.body)
        expect(response_json).to have_key('id')
        expect(response_json['id']).to be
        expect(response_json).to have_key('project')
        expect(response_json['project']).to eq({'id' => project.uuid})
        expect(response_json).to have_key('user')
        expect(response_json['user']['id']).to eq(user.uuid)
        expect(response_json['user']['full_name']).to eq(user.display_name)
        expect(response_json['user']['email']).to eq(user.email)
        expect(response_json).to have_key('project_roles')
      end

      it 'should require an auth token' do
        expect {
          post "/api/v1/project/#{project.uuid}/affiliates", payload.to_json, json_headers
          expect(response.status).to eq(400)
        }.not_to change{Membership.count}
      end
    end

    context 'with invalid payload' do
      let(:payload) {{
          user: {
            id: nil
          },
          project_roles: [{id: 'principal_investigator'}]
        }}
      before do
        expect {
          post "/api/v1/project/#{project.uuid}/affiliates", payload.to_json, json_headers_with_auth
        }.not_to change{Membership.count}
      end
      it_behaves_like 'a validation failure'
    end
  end

  describe 'List project affiliates' do
    it 'should return a list of affiliates for a given project' do
      expect(membership).to be_persisted
      get "/api/v1/project/#{membership.project.uuid}/affiliates", nil, json_headers_with_auth
      expect(response.status).to eq(200)
      expect(response.body).to be
      expect(response.body).not_to eq('null')
      expect(response.body).to include(serialized_membership)
    end

    it 'should require an auth token' do
      get "/api/v1/project/#{project.uuid}/affiliates", nil, json_headers
      expect(response.status).to eq(400)
    end
  end

  describe 'View project affiliate details' do
    let(:affiliate_uuid) { membership.id }
    it 'should return a json payload of the affiliate associated with id' do
      get "/api/v1/project/#{project.uuid}/affiliates/#{affiliate_uuid}", nil, json_headers_with_auth
      expect(response.status).to eq(200)
      expect(response.body).to be
      expect(response.body).not_to eq('null')
      expect(response.body).to include(serialized_membership)
    end

    it 'should require an auth token' do
      get "/api/v1/project/#{project.uuid}/affiliates/#{affiliate_uuid}", nil, json_headers
      expect(response.status).to eq(400)
    end
  end

  describe 'Update a project affiliate' do
    let(:project_uuid) { membership.project.uuid }
    let(:affiliate_uuid) { membership.id }
    context 'with a valid payload' do
      let(:payload) {{
          user: {id: user.uuid},
          external_person: nil,
          project_roles: [{id: 'research_coordinator'}]
      }}
      it 'should update the project affiliate associated with id using the supplied payload' do
        put "/api/v1/project/#{project_uuid}/affiliates/#{affiliate_uuid}", payload.to_json, json_headers_with_auth
        expect(response.status).to eq(200)
        expect(response.body).to be
        expect(response.body).not_to eq('null')

        response_json = JSON.parse(response.body)
        expect(response_json).to have_key('id')
        expect(response_json['id']).to be
        expect(response_json).to have_key('project')
        expect(response_json['project']).to eq({'id' => project_uuid})
        expect(response_json).to have_key('user')
        expect(response_json['user']['id']).to eq(user.uuid)
        expect(response_json['user']['full_name']).to eq(user.display_name)
        expect(response_json['user']['email']).to eq(user.email)
        expect(response_json).to have_key('project_roles')
        membership.reload
        expect(membership.id).to eq(affiliate_uuid)
        expect(membership.project.uuid).to eq(project_uuid)
        expect(membership.user.uuid).to eq(payload[:user][:id])
      end

      it 'should require an auth token' do
        put "/api/v1/project/#{project_uuid}/affiliates/#{affiliate_uuid}", payload.to_json, json_headers
        expect(response.status).to eq(400)
      end
    end

    context 'with a invalid payload' do
      let(:payload) {{
          user: {id: nil},
          project_roles: [{id: 'principal_investigator'}]
      }}
      before do
        put "/api/v1/project/#{project_uuid}/affiliates/#{affiliate_uuid}", payload.to_json, json_headers_with_auth
      end
      it_behaves_like 'a validation failure'
    end
  end

  describe 'Delete a project affiliate' do
    let(:affiliate_uuid) { membership.id }
    it 'remove the project affiliation associated with id' do
      expect(membership).to be_persisted
      expect {
        delete "/api/v1/project/#{project.uuid}/affiliates/#{affiliate_uuid}", nil, json_headers_with_auth
        expect(response.status).to eq(204)
        expect(response.body).not_to eq('null')
        expect(response.body).to be
      }.to change{Membership.count}.by(-1)
    end

    it 'should require an auth token' do
      delete "/api/v1/project/#{project.uuid}/affiliates/#{affiliate_uuid}", nil, json_headers
      expect(response.status).to eq(400)
    end
  end
end
