# frozen_string_literal: true

RSpec.describe Hyrax::ThumbnailPathService, singletenant: true do
  let(:file_set) { Hyrax::FileSet.new(id: 'fs1', label: label) }
  let(:work) { GenericWork.new(id: 'w1', thumbnail_id: 'fs1') }
  let(:type_service) { instance_double(Hyrax::FileSetTypeService, audio?: audio, video?: video, metadata: nil) }
  let(:audio) { false }
  let(:video) { false }
  let(:label) { 'msa-vid-001.mp4' }

  before do
    allow(Site).to receive(:instance).and_return(double('Site', default_work_image: nil, default_collection_image: nil))
    allow(Hyrax::FileSetTypeService).to receive(:new).with(file_set: file_set).and_return(type_service)
    allow(described_class).to receive(:fetch_thumbnail).with(work).and_return(file_set)
    allow(described_class).to receive(:thumbnail?).with(file_set).and_return(false)
  end

  describe '.call' do
    context 'when the mime type identifies video' do
      let(:video) { true }

      it 'returns the media icon' do
        expect(described_class.call(work)).to eq described_class.media_image
      end
    end

    context 'when the mime type identifies audio' do
      let(:audio) { true }

      it 'returns the audio icon' do
        expect(described_class.call(work)).to include 'audio'
      end
    end

    # Characterization sets the mime type, and it had not run for these file sets
    # after the FITS outage in notch8/hykuup_knapsack#730.
    context 'when characterization has not run' do
      it 'falls back to the extension for video' do
        expect(described_class.call(work)).to eq described_class.media_image
      end

      context 'with an audio extension' do
        let(:label) { 'msa-aud-001.mp3' }

        it 'falls back to the extension for audio' do
          expect(described_class.call(work)).to include 'audio'
        end
      end

      context 'with a non-media extension' do
        let(:label) { 'hhs-doc-001.pdf' }

        it 'leaves the generic default in place' do
          expect(described_class.call(work)).to eq described_class.send(:default_image)
        end
      end
    end

    context 'when the admin chose a default work image' do
      let(:video) { true }

      before do
        uploader = double('Uploader', url: '/uploads/site/default_work_image/chosen.png')
        allow(Site).to receive(:instance)
          .and_return(double('Site', default_work_image: uploader, default_collection_image: nil))
      end

      it 'respects their choice over the type icon' do
        expect(described_class.call(work)).to eq '/uploads/site/default_work_image/chosen.png'
      end
    end
  end
end
