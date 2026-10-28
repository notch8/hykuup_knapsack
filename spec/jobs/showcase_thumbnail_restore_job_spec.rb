# frozen_string_literal: true

RSpec.describe ShowcaseThumbnailRestoreJob do
  let(:dir) { Pathname(Dir.mktmpdir) }
  let(:saved) { dir.join('saved.jpeg') }
  let(:live) { dir.join('live-thumbnail.jpeg') }
  let(:mp4) { dir.join('live.mp4') }
  let(:entries) { [{ 'identifier' => 'msa-vid-001', 'file' => saved.to_s }] }
  let(:work) { double(id: 'work-1', bulkrax_identifier: ['msa-vid-001'], thumbnail_id: Valkyrie::ID.new('fs-1')) }
  let(:rescheduled) { double(perform_later: true) }

  before do
    File.write(saved, 'chosen frame')
    allow(Hyku::Application).to receive(:work_types).and_return([GenericWorkResource])
    allow(Hyrax.query_service).to receive(:find_all_of_model).with(model: GenericWorkResource).and_return([work])
    allow(Hyrax::DerivativePath).to receive(:derivative_path_for_reference).with('fs-1', 'thumbnail').and_return(live.to_s)
    allow(Hyrax::DerivativePath).to receive(:derivative_path_for_reference).with('fs-1', 'mp4').and_return(mp4.to_s)
    allow(Hyrax.index_adapter).to receive(:save)
    allow(described_class).to receive(:set).and_return(rescheduled)
  end

  after { FileUtils.rm_rf(dir) }

  context 'once the video is fully processed' do
    before do
      File.write(live, 'auto frame')
      File.write(mp4, 'video')
    end

    it 'replaces the thumbnail, reindexes and checks once more in case the job reruns' do
      described_class.perform_now(entries)

      expect(File.read(live)).to eq 'chosen frame'
      expect(Hyrax.index_adapter).to have_received(:save).with(resource: work)
      expect(rescheduled).to have_received(:perform_later)
        .with([hash_including('indexed' => true, 'mp4_seen' => true)], 2)
    end

    it 'stops on the check after that' do
      described_class.perform_now([entries.first.merge('indexed' => false, 'mp4_seen' => true)])

      expect(described_class).not_to have_received(:set)
    end
  end

  context 'when reindexing failed after the copy' do
    before do
      File.write(live, 'chosen frame')
      File.write(mp4, 'video')
    end

    it 'reindexes on the retry even though the thumbnail already matches' do
      described_class.perform_now(entries)

      expect(Hyrax.index_adapter).to have_received(:save).with(resource: work)
    end
  end

  context 'once the thumbnail is written but the video is still encoding' do
    before { File.write(live, 'auto frame') }

    it 'restores the thumbnail now and checks again in case a retry rewrites it' do
      described_class.perform_now(entries)

      expect(File.read(live)).to eq 'chosen frame'
      expect(rescheduled).to have_received(:perform_later).with(entries, 2)
    end
  end

  context 'when the saved thumbnail is already in place and indexed' do
    before do
      File.write(live, 'chosen frame')
      File.write(mp4, 'video')
    end

    it 'leaves the work alone' do
      described_class.perform_now([entries.first.merge('indexed' => true, 'mp4_seen' => true)])

      expect(Hyrax.index_adapter).not_to have_received(:save)
      expect(described_class).not_to have_received(:set)
    end
  end

  context 'before the video has a thumbnail' do
    it 'checks again later' do
      described_class.perform_now(entries)

      expect(described_class).to have_received(:set).with(wait: described_class::RECHECK_WAIT)
      expect(rescheduled).to have_received(:perform_later).with(entries, 2)
    end

    it 'gives up after the last check' do
      described_class.perform_now(entries, described_class::MAX_CHECKS)

      expect(described_class).not_to have_received(:set)
    end
  end

  context 'before the reimported work has its file set' do
    let(:work) { double(id: 'work-1', bulkrax_identifier: ['msa-vid-001'], thumbnail_id: nil) }

    it 'checks again later' do
      described_class.perform_now(entries)

      expect(rescheduled).to have_received(:perform_later).with(entries, 2)
    end
  end

  context 'when the work is gone after the reimport' do
    before { allow(Hyrax.query_service).to receive(:find_all_of_model).and_return([]) }

    it 'skips it without checking again' do
      described_class.perform_now(entries)

      expect(described_class).not_to have_received(:set)
    end
  end
end
