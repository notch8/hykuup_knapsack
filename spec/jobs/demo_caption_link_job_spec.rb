# frozen_string_literal: true

RSpec.describe DemoCaptionLinkJob do
  let(:work) { double(id: Valkyrie::ID.new('work-1')) }
  let(:reloaded_work) { double(id: work.id) }
  let(:audio) { file_set('fs-audio', 'talk.mp3') }
  let(:caption) { file_set('fs-vtt', 'talk.vtt') }
  let(:file_sets) { [audio, caption] }
  let(:originals) do
    { audio => original('talk.mp3', 'application/octet-stream'), caption => original('talk.vtt', 'text/plain') }
  end
  let(:rescheduled) { double(perform_later: true) }

  def file_set(id, name, transcript_ids: [])
    Struct.new(:id, :label, :title, :transcript_ids).new(Valkyrie::ID.new(id), name, [name], transcript_ids)
  end

  def original(name, mime_type)
    double(original_filename: name, mime_type:)
  end

  before do
    allow(Hyku::Application).to receive(:work_types).and_return([GenericWorkResource])
    allow(Hyrax.query_service).to receive(:find_all_of_model).with(model: GenericWorkResource).and_return([work])
    allow(Hyrax.query_service).to receive(:find_by).with(id: work.id).and_return(reloaded_work)
    allow(Hyrax.custom_queries).to receive(:find_child_file_sets).with(resource: work).and_return(file_sets)
    allow(Hyrax.custom_queries).to receive(:find_original_file) { |file_set:| originals[file_set] }
    allow(Hyrax.persister).to receive(:save) { |resource:| resource }
    allow(Hyrax.index_adapter).to receive(:save)
    allow(described_class).to receive(:set).and_return(rescheduled)
  end

  context 'once the files are ingested but not yet characterized' do
    it 'links the captions to the audio by file name' do
      described_class.perform_now

      expect(audio.transcript_ids).to eq ['fs-vtt']
      expect(described_class).not_to have_received(:set)
    end

    it 'titles a lone caption still named after its file' do
      described_class.perform_now

      expect(caption.title).to eq [described_class::CAPTION_TITLE]
    end

    it 'saves the work so its cached manifest is replaced' do
      described_class.perform_now

      expect(Hyrax.persister).to have_received(:save).with(resource: reloaded_work)
    end
  end

  context 'when a work has two captions' do
    let(:second) { file_set('fs-vtt-es', 'talk.es.vtt') }
    let(:file_sets) { [audio, caption, second] }

    before { originals[second] = original('talk.es.vtt', 'text/vtt') }

    it 'links both and leaves their titles to tell them apart' do
      described_class.perform_now

      expect(audio.transcript_ids).to contain_exactly('fs-vtt', 'fs-vtt-es')
      expect([caption.title, second.title]).to eq [['talk.vtt'], ['talk.es.vtt']]
    end
  end

  context 'when the work is already linked and titled' do
    let(:audio) { file_set('fs-audio', 'talk.mp3', transcript_ids: [Valkyrie::ID.new('fs-vtt')]) }

    before { caption.title = ['Captions'] }

    it 'saves nothing' do
      described_class.perform_now

      expect(Hyrax.persister).not_to have_received(:save)
    end
  end

  context 'while a file is still being ingested, so its name is not known yet' do
    before { originals[audio] = nil }

    it 'leaves the work alone and checks again later' do
      described_class.perform_now

      expect(audio.transcript_ids).to be_empty
      expect(described_class).to have_received(:set).with(wait: described_class::RECHECK_WAIT)
      expect(rescheduled).to have_received(:perform_later).with(2)
    end

    it 'gives up after the last check' do
      described_class.perform_now(described_class::MAX_CHECKS)

      expect(described_class).not_to have_received(:set)
    end
  end

  context 'for a work without captions' do
    let(:file_sets) { [audio] }

    it 'saves nothing and stops' do
      described_class.perform_now

      expect(Hyrax.persister).not_to have_received(:save)
      expect(described_class).not_to have_received(:set)
    end
  end

  context 'when file sets have no transcript_ids' do
    let(:audio) { Struct.new(:id, :label, :title).new(Valkyrie::ID.new('fs-audio'), 'talk.mp3', ['talk.mp3']) }
    let(:caption) { Struct.new(:id, :label, :title).new(Valkyrie::ID.new('fs-vtt'), 'talk.vtt', ['talk.vtt']) }

    it 'skips the work without checking again' do
      described_class.perform_now

      expect(Hyrax.persister).not_to have_received(:save)
      expect(described_class).not_to have_received(:set)
    end
  end
end
