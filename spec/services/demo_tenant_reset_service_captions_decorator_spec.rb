# frozen_string_literal: true

RSpec.describe DemoTenantResetService, singletenant: true do
  let(:service) { described_class.new(account:, seed_csv_path: '/seed/meridian/metadata.csv') }
  let(:account) { instance_double(Account, name: 'meridian', cname: 'meridian.example.com', tenant: 'meridian-uuid') }

  before { allow(DemoCaptionLinkJob).to receive(:perform_later) }

  it 'queues caption linking once the seed is imported' do
    allow(Bulkrax::ImporterJob).to receive(:perform_now)
    allow(File).to receive(:exist?).and_call_original
    allow(File).to receive(:exist?).with('/seed/meridian/metadata.csv').and_return(true)
    allow(service).to receive_messages(ensure_default_groups!: nil, create_importer!: double(id: 1),
                                       drain_import_jobs!: nil, verify_import!: nil)

    service.send(:import_seed!)

    expect(DemoCaptionLinkJob).to have_received(:perform_later)
  end

  it 'queues nothing when the import fails' do
    allow(File).to receive(:exist?).and_call_original
    allow(File).to receive(:exist?).with('/seed/meridian/metadata.csv').and_return(false)

    expect { service.send(:import_seed!) }.to raise_error(DemoTenantResetService::ImportFailed)
    expect(DemoCaptionLinkJob).not_to have_received(:perform_later)
  end
end
