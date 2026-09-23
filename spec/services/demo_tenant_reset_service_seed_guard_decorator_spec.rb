# frozen_string_literal: true

RSpec.describe DemoTenantResetService, singletenant: true do
  let(:account) { instance_double(Account, cname: 'sandbox.example.com', public_demo_tenant?: true) }
  let(:service) { described_class.new(account:, seed_csv_path:) }

  describe 'wiping with a missing seed payload' do
    context 'when the seed csv is absent' do
      let(:seed_csv_path) { 'tmp/imports/sandbox/seed/does-not-exist.csv' }

      it 'refuses before destroying anything' do
        expect { service.send(:wipe_content!) }
          .to raise_error(described_class::ImportFailed, /refusing to wipe sandbox.example.com/)
      end
    end

    context 'when the seed csv is present' do
      let(:seed_csv_path) { 'Gemfile' } # any file that exists; content is irrelevant here

      it 'proceeds to the wipe' do
        allow(FeaturedWork).to receive(:destroy_all)
        allow(FeaturedCollection).to receive(:destroy_all)
        allow(service).to receive(:destroy_all_of_model)
        allow(service).to receive(:purge_solr_index!)
        allow(service).to receive(:reindex_admin_sets!)

        expect { service.send(:wipe_content!) }.not_to raise_error
        expect(FeaturedWork).to have_received(:destroy_all)
      end
    end

    # Without a seed path the reset legitimately restores an empty but branded
    # tenant, so the guard must not block that case.
    context 'when no seed path is configured' do
      let(:seed_csv_path) { nil }

      it 'proceeds to the wipe' do
        allow(FeaturedWork).to receive(:destroy_all)
        allow(FeaturedCollection).to receive(:destroy_all)
        allow(service).to receive(:destroy_all_of_model)
        allow(service).to receive(:purge_solr_index!)
        allow(service).to receive(:reindex_admin_sets!)

        expect { service.send(:wipe_content!) }.not_to raise_error
      end
    end
  end
end
