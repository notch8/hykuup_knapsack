# frozen_string_literal: true

RSpec.describe DemoTenantResetService, singletenant: true do
  let(:service) { described_class.new(account:) }
  let(:root) { Pathname(Dir.mktmpdir) }
  let(:account) do
    instance_double(Account, name: 'meridian', cname: 'meridian.example.com', tenant: 'meridian-uuid',
                             demo_tenant_snapshot: { 'video_thumbnails' => entries })
  end
  let(:entries) { nil }

  before { allow(Hyrax.config).to receive(:derivatives_path).and_return(root.to_s) }
  after { FileUtils.rm_rf(root) }

  describe 'capturing video thumbnails for the snapshot' do
    let(:video) { double(id: Valkyrie::ID.new('video-1'), bulkrax_identifier: ['msa-vid-001']) }
    let(:image) { double(id: Valkyrie::ID.new('image-1'), bulkrax_identifier: ['msa-img-001']) }
    let(:thumbnail) { root.join('derivatives', 'video-1-thumbnail.jpeg') }

    before do
      FileUtils.mkdir_p(thumbnail.dirname)
      File.write(thumbnail, 'chosen frame')
      allow(Hyku::Application).to receive(:work_types).and_return([GenericWorkResource])
      allow(Hyrax.query_service).to receive(:find_all_of_model).with(model: GenericWorkResource).and_return([video, image])
      allow(service).to receive(:video_thumbnail_path).with(video).and_return(thumbnail.to_s)
      allow(service).to receive(:video_thumbnail_path).with(image).and_return(nil)
    end

    it 'copies each video thumbnail aside, recorded by import identifier' do
      entries = service.send(:capture_video_thumbnails, root.join('capture'))

      expect(entries.map { |e| e['identifier'] }).to eq ['msa-vid-001']
      expect(File.read(entries.first['file'])).to eq 'chosen frame'
    end

    it 'saves them on the account with the rest of the snapshot' do
      allow(account).to receive(:public_demo_tenant?).and_return(false)
      allow(account).to receive(:demo_tenant_snapshot).and_return(nil)
      allow(account).to receive(:update!)
      allow(service).to receive(:within_tenant).and_yield
      allow(service).to receive(:featured_collection_entries).and_return([])
      allow(service).to receive(:capture_collection_branding).and_return([])

      service.snapshot!

      expect(account).to have_received(:update!)
        .with(demo_tenant_snapshot: hash_including('video_thumbnails' => [hash_including('identifier' => 'msa-vid-001')]))
        .at_least(:once)
    end
  end

  describe 'taking a snapshot while thumbnails are still being restored' do
    before do
      allow(account).to receive(:public_demo_tenant?).and_return(false)
      GoodJob::Job.create!(id: SecureRandom.uuid, active_job_id: SecureRandom.uuid, queue_name: 'default',
                           job_class: 'ShowcaseThumbnailRestoreJob', serialized_params: { 'tenant' => 'meridian-uuid' })
    end

    it 'refuses, so the automatic thumbnails are not saved over the chosen ones' do
      expect { service.snapshot!(force: true) }
        .to raise_error(DemoTenantResetServiceVideoThumbnailsDecorator::RestoreInProgress)
    end
  end

  describe 'deciding which thumbnails to save' do
    subject(:path) { service.send(:video_thumbnail_path, work) }

    let(:work) { double(thumbnail_id: Valkyrie::ID.new('fs-1')) }
    let(:file_set) { double(id: Valkyrie::ID.new('fs-1')) }
    let(:thumbnail) { root.join('fs-1-thumbnail.jpeg') }

    before do
      File.write(thumbnail, 'frame')
      allow(service).to receive(:find_resource).with(work.thumbnail_id).and_return(file_set)
      allow(Hyrax::DerivativePath).to receive(:derivative_path_for_reference).with('fs-1', 'thumbnail').and_return(thumbnail.to_s)
    end

    it 'saves the thumbnail of a video' do
      allow(Hyrax.custom_queries).to receive(:find_original_file).with(file_set:).and_return(double(mime_type: 'video/mp4'))

      expect(path).to eq thumbnail.to_s
    end

    it 'skips an image' do
      allow(Hyrax.custom_queries).to receive(:find_original_file).with(file_set:).and_return(double(mime_type: 'image/jpeg'))

      expect(path).to be_nil
    end

    it 'skips a file set with no original file' do
      allow(Hyrax.custom_queries).to receive(:find_original_file).and_raise(Valkyrie::Persistence::ObjectNotFoundError)

      expect(path).to be_nil
    end

    context 'for a work without a thumbnail' do
      let(:work) { double(thumbnail_id: nil) }

      it('skips it') { expect(path).to be_nil }
    end
  end

  describe 'restoring after the reimport' do
    before do
      allow(Hyrax.query_service).to receive(:find_all_of_model).and_return([])
      allow(ShowcaseThumbnailRestoreJob).to receive(:perform_later)
    end

    context 'with saved thumbnails' do
      let(:entries) { [{ 'identifier' => 'msa-vid-001', 'file' => '/saved/video-1.jpeg' }] }

      it 'queues a job to put them back once the videos are processed' do
        service.send(:restore_featured_works!)

        expect(ShowcaseThumbnailRestoreJob).to have_received(:perform_later).with(entries)
      end
    end

    context 'when the snapshot predates video thumbnails' do
      it 'queues nothing' do
        service.send(:restore_featured_works!)

        expect(ShowcaseThumbnailRestoreJob).not_to have_received(:perform_later)
      end
    end
  end
end
