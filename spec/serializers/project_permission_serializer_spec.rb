require 'rails_helper'

RSpec.describe ProjectPermissionSerializer, type: :serializer do
  let(:resource) { FactoryGirl.build(:project_permission) }

  it_behaves_like 'a json serializer' do
    it 'should have expected keys and values' do
      is_expected.to have_key('user')
      is_expected.to have_key('project')
      is_expected.to have_key('auth_role')
      expect(subject['user']).to eq({
        'id' => resource.user.id,
        'username' => resource.user.username,
        'full_name' => resource.user.display_name
      })
      expect(resource.auth_role).to be
      expect(subject['auth_role']).to eq({
        'id' => resource.auth_role.id,
        'name' => resource.auth_role.name,
        'description' => resource.auth_role.description
      })
      expect(subject['project']).to eq({'id' => resource.project.id})
    end
  end
end