# frozen_string_literal: true

RSpec.describe DemoTenantResetService, singletenant: true do
  let(:service) { described_class.new(account:) }

  describe 'recording featured collections for the snapshot' do
    let(:account) { instance_double(Account, name: 'ellison', cname: 'ellison.example.com') }

    it 'records each featured collection by import identifier and order' do
      FeaturedCollection.create!(collection_id: 'old-a', order: 2)
      FeaturedCollection.create!(collection_id: 'old-b', order: 1)
      allow(service).to receive(:find_resource).with('old-a').and_return(double(bulkrax_identifier: ['col-a']))
      allow(service).to receive(:find_resource).with('old-b').and_return(double(bulkrax_identifier: ['col-b']))

      expect(service.send(:featured_collection_entries))
        .to contain_exactly({ 'identifier' => 'col-a', 'order' => 2 }, { 'identifier' => 'col-b', 'order' => 1 })
    end

    it 'saves them on the account with the rest of the snapshot' do
      allow(account).to receive(:public_demo_tenant?).and_return(false)
      allow(account).to receive(:demo_tenant_snapshot).and_return(nil)
      allow(account).to receive(:update!)
      allow(service).to receive(:within_tenant).and_yield
      allow(service).to receive(:featured_collection_entries).and_return([{ 'identifier' => 'col-a', 'order' => 1 }])

      service.snapshot!

      expect(account).to have_received(:update!)
        .with(demo_tenant_snapshot: hash_including('featured_collections' => [{ 'identifier' => 'col-a', 'order' => 1 }]))
        .at_least(:once)
    end

    it 'skips a featured collection that no longer exists' do
      FeaturedCollection.create!(collection_id: 'gone', order: 1)
      allow(service).to receive(:find_resource).with('gone').and_return(nil)

      expect(service.send(:featured_collection_entries)).to be_empty
    end
  end

  describe 'restoring featured collections after the reimport' do
    let(:account) do
      instance_double(Account, name: 'ellison', cname: 'ellison.example.com',
                               demo_tenant_snapshot: { 'featured_collections' => entries })
    end
    let(:entries) do
      [{ 'identifier' => 'col-a', 'order' => 2 }, { 'identifier' => 'col-missing', 'order' => 1 }]
    end
    let(:reimported) { double(id: Valkyrie::ID.new('new-a'), bulkrax_identifier: ['col-a']) }

    before do
      FeaturedCollection.create!(collection_id: 'stale', order: 3)
      allow(Hyrax.query_service).to receive(:find_all_of_model)
        .with(model: Hyrax.config.collection_class).and_return([reimported])
    end

    it 'features the reimported collections in their recorded order and drops stale rows' do
      service.send(:restore_featured_collections!)

      expect(FeaturedCollection.pluck(:collection_id, :order)).to eq [['new-a', 2]]
    end

    it 'runs as part of restoring featured works, even when no works are featured' do
      service.send(:restore_featured_works!)

      expect(FeaturedCollection.pluck(:collection_id)).to eq ['new-a']
    end

    context 'when the snapshot predates featured collections' do
      let(:entries) { nil }

      it 'leaves the featured collections alone' do
        service.send(:restore_featured_collections!)

        expect(FeaturedCollection.pluck(:collection_id)).to eq ['stale']
      end
    end
  end
end
