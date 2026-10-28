# frozen_string_literal: true

RSpec.describe DemoTenantResetService, singletenant: true do
  subject(:pending) { described_class.new(account:).send(:pending_good_jobs) }

  let(:account) do
    instance_double(Account, name: 'sandbox', cname: 'sandbox.example.com', tenant: 'tenant-uuid', public_demo_tenant?: true)
  end

  before do
    %w[Bulkrax::ImportWorkJob ValkyrieCreateLargeDerivativesJob].each do |job_class|
      GoodJob::Job.create!(id: SecureRandom.uuid, active_job_id: SecureRandom.uuid, queue_name: 'default',
                           job_class:, serialized_params: { 'tenant' => 'tenant-uuid' }, scheduled_at: 1.minute.ago)
    end
  end

  it 'waits for the Bulkrax import jobs, not derivatives still running' do
    expect(pending).to eq 1
  end
end
