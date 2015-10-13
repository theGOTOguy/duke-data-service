require 'rails_helper'

RSpec.describe FolderSerializer, type: :serializer do
  let(:resource) { child_folder }
  let(:child_folder) { FactoryGirl.create(:folder, :with_parent) }
  let(:root_folder) { FactoryGirl.create(:folder, :root) }

  it_behaves_like 'a json serializer' do
    it 'should have expected keys and values' do
      is_expected.to have_key('id')
      is_expected.to have_key('parent')
      expect(subject['parent']).to have_key('kind')
      expect(subject['parent']).to have_key('id')
      is_expected.to have_key('name')
      is_expected.to have_key('project')
      expect(subject['project']).to have_key('id')
      is_expected.to have_key('ancestors')
      is_expected.to have_key('is_deleted')

      expect(subject['id']).to eq(resource.id)
      expect(subject['parent']['kind']).to eq(resource.parent.kind)
      expect(subject['parent']['id']).to eq(resource.parent.id)
      expect(subject['name']).to eq(resource.name)
      expect(subject['project']['id']).to eq(resource.project_id)
      expect(subject['is_deleted']).to eq(resource.is_deleted)
    end

    describe 'ancestors' do
      it 'should return the project and parent' do
        expect(resource.project).to be
        expect(resource.parent).to be
        expect(subject['ancestors']).to eq [
          {
            'kind' => resource.project.kind,
            'id' => resource.project.id,
            'name' => resource.project.name
          },
          {
            'kind' => resource.parent.kind,
            'id' => resource.parent.id,
            'name' => resource.parent.name
          }
        ]
      end
    end

    context 'without a parent' do
      let(:resource) { root_folder }

      it 'should have expected keys and values' do
        is_expected.to have_key('parent')
        expect(subject['parent']).to have_key('kind')
        expect(subject['parent']).to have_key('id')

        expect(subject['parent']['kind']).to eq(resource.project.kind)
        expect(subject['parent']['id']).to eq(resource.project.id)
      end

      describe 'ancestors' do
        it 'should return the project' do
          expect(resource.project).to be
          expect(subject['ancestors']).to eq [
            {
              'kind' => resource.project.kind,
              'id' => resource.project.id,
              'name' => resource.project.name }
          ]
        end
      end
    end
  end
end