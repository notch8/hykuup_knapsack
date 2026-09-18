# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Hyrax::UploadsController, type: :controller do
  # The uploads route lives in the Hyrax engine, not the host application.
  routes { Hyrax::Engine.routes }

  let(:user) { FactoryBot.create(:user) }
  # fixture_paths points at hyrax-webapp; reach the knapsack's own fixtures explicitly.
  let(:fixture) { HykuKnapsack::Engine.root.join('spec', 'fixtures', 'files', 'malformed.pdf') }
  let(:file) { Rack::Test::UploadedFile.new(fixture, 'application/pdf') }
  let(:file_size) { File.size(fixture) }

  def stub_limit(bytes)
    allow(Site).to receive(:account).and_return(instance_double(Account, file_size_limit: bytes&.to_s))
  end

  before { sign_in user }

  describe 'POST #create' do
    context 'with no limit configured' do
      it 'accepts the upload rather than rejecting everything' do
        stub_limit(nil)
        post :create, params: { files: [file], format: 'json' }
        expect(response).not_to have_http_status(:payload_too_large)
      end
    end

    context 'with a limit the file fits inside' do
      it 'accepts the upload' do
        stub_limit(file_size + 1)
        post :create, params: { files: [file], format: 'json' }
        expect(response).not_to have_http_status(:payload_too_large)
      end
    end

    context 'with a limit the file exceeds' do
      before { stub_limit(file_size - 1) }

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

    # The bug this override exists for. Hyrax appends only when CONTENT-RANGE starts
    # exactly where the file on disk ends, so each request is small and the assembled
    # file is not.
    describe 'the chunked path' do
      let(:existing) { Hyrax::UploadedFile.create!(file:, user:) }
      let(:on_disk) { File.size(existing.file.path) }

      def append_chunk
        request.headers['CONTENT-RANGE'] = "bytes #{on_disk}-#{(on_disk + file_size) - 1}/#{on_disk + file_size}"
        post :create, params: { id: existing.id, files: [file], format: 'json' }
      end

      it 'refuses an append that would take the assembled file over the limit' do
        stub_limit(on_disk + file_size - 1)
        append_chunk

        expect(response).to have_http_status(:payload_too_large)
      end

      it 'accepts an append that stays under the limit' do
        stub_limit(on_disk + file_size + 1)
        append_chunk

        expect(response).not_to have_http_status(:payload_too_large)
      end

      # Without a CONTENT-RANGE header Hyrax replaces rather than appends, so counting
      # the bytes already on disk would reject a legitimate replacement.
      it 'does not count existing bytes when the request replaces rather than appends' do
        stub_limit(file_size + 1)
        post :create, params: { id: existing.id, files: [file], format: 'json' }

        expect(response).not_to have_http_status(:payload_too_large)
      end
    end
  end
end
