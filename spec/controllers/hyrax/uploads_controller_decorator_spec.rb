# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Hyrax::UploadsController, type: :controller do
  # The uploads route lives in the Hyrax engine, not the host application.
  routes { Hyrax::Engine.routes }

  let(:user) { FactoryBot.create(:user) }
  # fixture_paths points at hyrax-webapp; reach the knapsack's own fixtures explicitly.
  let(:fixture) { HykuKnapsack::Engine.root.join('spec', 'fixtures', 'files', 'malformed.pdf') }
  let(:file) { Rack::Test::UploadedFile.new(fixture, 'application/pdf') }

  before { sign_in user }

  describe 'POST #create' do
    context 'when the site has no upload limit' do
      before { allow(Site).to receive(:account).and_return(instance_double(Account, file_size_limit: nil)) }

      it 'accepts the upload' do
        post :create, params: { files: [file], format: 'json' }
        expect(response).not_to have_http_status(:payload_too_large)
      end
    end

    context 'when the file is under the limit' do
      before { allow(Site).to receive(:account).and_return(instance_double(Account, file_size_limit: 5.megabytes.to_s)) }

      it 'accepts the upload' do
        post :create, params: { files: [file], format: 'json' }
        expect(response).not_to have_http_status(:payload_too_large)
      end
    end

    context 'when the file is over the limit' do
      before { allow(Site).to receive(:account).and_return(instance_double(Account, file_size_limit: '10')) }

      it 'refuses with 413 and an error blueimp can render' do
        post :create, params: { files: [file], format: 'json' }

        expect(response).to have_http_status(:payload_too_large)
        expect(JSON.parse(response.body)['files'].first['error']).to match(/upload limit/)
      end

      it 'creates no UploadedFile' do
        expect { post :create, params: { files: [file], format: 'json' } }
          .not_to change(Hyrax::UploadedFile, :count)
      end
    end

    # The bug this override exists for: each chunk is small, the assembled file is not.
    context 'when a chunk would take an existing upload over the limit' do
      let(:existing) { Hyrax::UploadedFile.create!(file:, user:) }

      before do
        allow(Site).to receive(:account)
          .and_return(instance_double(Account, file_size_limit: (File.size(existing.file.path) + 1).to_s))
      end

      it 'refuses the chunk' do
        post :create, params: { id: existing.id, files: [file], format: 'json' }

        expect(response).to have_http_status(:payload_too_large)
      end
    end
  end
end
