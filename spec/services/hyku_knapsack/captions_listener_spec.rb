# frozen_string_literal: true

RSpec.describe HykuKnapsack::CaptionsListener do
  subject(:listener) { described_class.new }

  # Ingest stores the original file name as the label, before characterization sets a mime type.
  def file_set(label, ingested: true)
    file_set = Hyrax.persister.save(resource: Hyrax.config.file_set_class.new(label:))
    return file_set unless ingested

    file = Hyrax.persister.save(resource: Hyrax::FileMetadata.new(file_set_id: file_set.id, original_filename: label,
                                                                  pcdm_use: [Hyrax::FileMetadata::Use::ORIGINAL_FILE]))
    file_set.file_ids = [file.id]
    Hyrax.persister.save(resource: file_set)
  end

  def work(*members)
    Hyrax.persister.save(resource: GenericWorkResource.new(member_ids: members.map(&:id)))
  end

  def ingested(file_set)
    listener.on_object_membership_updated({ object: file_set })
  end

  def transcript_ids_of(resource)
    Array(Hyrax.query_service.find_by(id: resource.id).transcript_ids).map(&:to_s)
  end

  let(:audio) { file_set('talk.mp3') }
  let(:caption) { file_set('talk.vtt') }

  it 'links a caption to the audio ingested before it' do
    work(audio, caption)

    ingested(caption)

    expect(transcript_ids_of(audio)).to eq [caption.id.to_s]
    expect(transcript_ids_of(caption)).to be_empty
  end

  it 'links the captions ingested before the audio' do
    work(audio, caption)

    ingested(audio)

    expect(transcript_ids_of(audio)).to eq [caption.id.to_s]
  end

  it 'links every caption to every audio and video file set, whatever order they ingest in' do
    video = file_set('talk.mp4')
    spanish = file_set('talk.es.vtt')
    work(audio, video, caption, spanish)

    [caption, video, spanish, audio].each { |fs| ingested(fs) }

    expect(transcript_ids_of(audio)).to contain_exactly(caption.id.to_s, spanish.id.to_s)
    expect(transcript_ids_of(video)).to contain_exactly(caption.id.to_s, spanish.id.to_s)
  end

  it 'skips media not yet ingested, whose ingest links it later' do
    pending_audio = file_set('talk.mp3', ingested: false)
    work(pending_audio, caption)

    ingested(caption)

    expect(transcript_ids_of(pending_audio)).to be_empty
  end

  it 'leaves a caption unlinked by hand alone when another caption ingests' do
    other = file_set('other.vtt')
    work(audio, caption, other)
    ingested(audio)
    audio.transcript_ids = [caption.id.to_s]
    Hyrax.persister.save(resource: audio)

    ingested(caption)

    expect(transcript_ids_of(audio)).to eq [caption.id.to_s]
  end

  it 'does not look at works for other files or other events' do
    allow(Hyrax.custom_queries).to receive(:find_parent_work).and_call_original
    image = file_set('page.jpg')
    work(image, caption)

    ingested(image)
    listener.on_object_membership_updated({ object: work(audio, caption) })

    expect(Hyrax.custom_queries).not_to have_received(:find_parent_work)
  end

  it 'reindexes each linked file set in a job, which retries a failed Solr write' do
    allow(ReindexItemJob).to receive(:perform_later)
    work(audio, caption)

    ingested(caption)

    expect(ReindexItemJob).to have_received(:perform_later).with(audio.id.to_s).once
  end

  it 'logs rather than failing the ingest that published the event' do
    work(audio, caption)
    allow(Hyrax.custom_queries).to receive(:find_child_file_sets).and_raise(StandardError, 'boom')
    allow(Hyrax.logger).to receive(:error)

    expect { ingested(caption) }.not_to raise_error
    expect(Hyrax.logger).to have_received(:error).with(/boom/)
  end
end
