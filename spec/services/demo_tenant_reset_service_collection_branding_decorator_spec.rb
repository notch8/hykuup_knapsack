# frozen_string_literal: true

RSpec.describe DemoTenantResetService, singletenant: true do
  let(:service) { described_class.new(account:) }
  let(:branding_root) { Pathname(Dir.mktmpdir) }
  let(:storage) do
    Valkyrie::Storage::Disk.new(base_path: branding_root, path_generator: Hyrax::ValkyrieSimplePathGenerator)
  end

  before do
    allow(Hyrax.config).to receive(:branding_path).and_return(branding_root)
    allow(Hyrax.config).to receive(:branding_storage_adapter).and_return(storage)
  end

  after { FileUtils.rm_rf(branding_root) }

  def brand(collection_id, role, filename)
    source = Rails.root.join('tmp', "spec-#{SecureRandom.hex(4)}-#{filename}")
    File.write(source, "#{collection_id} #{role}")
    CollectionBrandingInfo.new(collection_id:, filename:, role:, alt_txt: "#{role} alt",
                               target_url: 'https://example.com').save(source.to_s)
  end

  describe 'capturing branding for the snapshot' do
    let(:account) { instance_double(Account, name: 'ellison', cname: 'ellison.example.com', tenant: 'ellison-uuid') }

    before do
      brand('old-a', 'banner', 'banner.png')
      brand('old-a', 'logo', 'logo.png')
      brand('gone', 'banner', 'gone.png')
      allow(service).to receive(:find_resource).with('old-a').and_return(double(bulkrax_identifier: ['col-a']))
      allow(service).to receive(:find_resource).with('gone').and_return(nil)
    end

    it 'copies each image aside and records it by import identifier' do
      entries = service.send(:capture_collection_branding, branding_root.join('capture'))

      expect(entries.map { |e| e.values_at('identifier', 'role', 'alt_text') })
        .to contain_exactly(['col-a', 'banner', 'banner alt'], ['col-a', 'logo', 'logo alt'])
      expect(entries.map { |e| File.read(e['file']) }).to contain_exactly('old-a banner', 'old-a logo')
      expect(entries.map { |e| e['file'] }).to all(start_with(branding_root.join('capture').to_s))
    end

    it 'keeps every copy inside the capture folder whatever the identifier says' do
      allow(service).to receive(:find_resource).with('old-a').and_return(double(bulkrax_identifier: ['../../escape']))

      files = service.send(:capture_collection_branding, branding_root.join('capture')).map { |e| e['file'] }

      expect(files.map { |f| File.expand_path(f) }).to all(start_with(branding_root.join('capture').to_s))
    end

    context 'when recapturing over an earlier snapshot' do
      let(:earlier) { branding_root.join('demo-snapshots', 'ellison-uuid', 'earlier') }

      before do
        FileUtils.mkdir_p(earlier)
        allow(account).to receive(:public_demo_tenant?).and_return(false)
        allow(account).to receive(:demo_tenant_snapshot).and_return(nil)
        allow(account).to receive(:update!)
        allow(service).to receive(:within_tenant).and_yield
        allow(service).to receive(:featured_collection_entries).and_return([])
      end

      it 'replaces the earlier copies once the new ones are saved' do
        service.snapshot!

        expect(earlier).not_to exist
        expect(branding_root.join('demo-snapshots', 'ellison-uuid').children.size).to eq 1
      end

      it 'finishes the snapshot and keeps both copies when the earlier ones cannot be cleared' do
        allow(FileUtils).to receive(:rm_rf).and_call_original
        allow(FileUtils).to receive(:rm_rf).with(earlier).and_raise(Errno::EACCES)

        snap = service.snapshot!

        expect(snap).to include('collection_branding', 'featured_collections')
        expect(branding_root.join('demo-snapshots', 'ellison-uuid').children.size).to eq 2
      end

      it 'keeps the earlier copies when a copy fails' do
        allow(FileUtils).to receive(:cp).and_raise(Errno::ENOSPC)

        expect { service.snapshot! }.to raise_error(Errno::ENOSPC)
        expect(branding_root.join('demo-snapshots', 'ellison-uuid').children).to eq [earlier]
        expect(account).not_to have_received(:update!)
      end
    end

    it 'saves them on the account with the rest of the snapshot' do
      allow(account).to receive(:public_demo_tenant?).and_return(false)
      allow(account).to receive(:demo_tenant_snapshot).and_return(nil)
      allow(account).to receive(:update!)
      allow(service).to receive(:within_tenant).and_yield
      allow(service).to receive(:capture_collection_branding).and_return([{ 'identifier' => 'col-a' }])

      service.snapshot!

      expect(account).to have_received(:update!)
        .with(demo_tenant_snapshot: hash_including('collection_branding' => [{ 'identifier' => 'col-a' }]))
        .at_least(:once)
    end
  end

  describe 'restoring branding after the reimport' do
    let(:account) do
      instance_double(Account, name: 'ellison', cname: 'ellison.example.com', tenant: 'ellison-uuid',
                               demo_tenant_snapshot: { 'collection_branding' => entries })
    end
    let(:saved) { branding_root.join('demo-snapshots', 'ellison-uuid', 'col-a', 'banner', 'banner.png') }
    let(:entries) do
      [{ 'identifier' => 'col-a', 'role' => 'banner', 'alt_text' => 'A banner', 'target_url' => '', 'file' => saved.to_s },
       { 'identifier' => 'col-missing', 'role' => 'logo', 'alt_text' => '', 'target_url' => '', 'file' => saved.to_s }]
    end
    let(:reimported) { double(id: Valkyrie::ID.new('new-a'), bulkrax_identifier: ['col-a']) }

    before do
      FileUtils.mkdir_p(saved.dirname)
      File.write(saved, 'banner image')
      brand('stale', 'banner', 'old.png')
      allow(Hyrax.query_service).to receive(:find_all_of_model)
        .with(model: Hyrax.config.collection_class).and_return([reimported])
      allow(Hyrax.index_adapter).to receive(:save)
    end

    it 'attaches the saved image to the reimported collection and keeps the snapshot copy' do
      service.send(:restore_collection_branding!)

      info = CollectionBrandingInfo.find_by!(collection_id: 'new-a')
      expect([info.role, info.alt_text]).to eq %w[banner] + ['A banner']
      expect(File.read(info.local_path)).to eq 'banner image'
      expect(saved).to exist
      expect(Hyrax.index_adapter).to have_received(:save).with(resource: reimported)
    end

    it 'drops branding rows and images left by the deleted collections' do
      stale_path = CollectionBrandingInfo.find_by!(collection_id: 'stale').local_path

      service.send(:restore_collection_branding!)

      expect(CollectionBrandingInfo.pluck(:collection_id)).to eq ['new-a']
      expect(File).not_to exist(stale_path)
    end

    it 'runs as part of restoring featured works' do
      service.send(:restore_featured_works!)

      expect(CollectionBrandingInfo.pluck(:collection_id)).to eq ['new-a']
    end

    context 'when the snapshot predates branding' do
      let(:entries) { nil }

      it 'still clears the stale rows' do
        service.send(:restore_collection_branding!)

        expect(CollectionBrandingInfo.count).to eq 0
      end
    end
  end
end
