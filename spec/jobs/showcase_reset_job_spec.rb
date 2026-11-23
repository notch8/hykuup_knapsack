# frozen_string_literal: true

RSpec.describe ShowcaseResetJob do
  let(:account) { FactoryBot.build(:account, name: 'ellison', tenant: 'ellison-uuid') }
  let(:service) { instance_double(DemoTenantResetService, reset!: true) }

  before do
    allow_any_instance_of(described_class).to receive(:current_account).and_return(account) # rubocop:disable RSpec/AnyInstance
    allow(DemoTenantResetService).to receive(:new).and_return(service)
  end

  it 'resets with the nightly reset settings and schedules no next run' do
    stub_const('ENV', ENV.to_h.merge('DEMO_SEED_CSV_PATH' => 'tmp/imports/%{tenant}/seed/metadata.csv'))

    expect { described_class.perform_now }.not_to have_enqueued_job
    expect(DemoTenantResetService).to have_received(:new)
      .with(hash_including(account:, seed_csv_path: 'tmp/imports/%{tenant}/seed/metadata.csv'))
    expect(service).to have_received(:reset!)
  end

  it 'drops thumbnail restores still waiting from the last reset, but not other tenants\' or running ones' do
    restore = lambda do |tenant, performed_at = nil|
      GoodJob::Job.create!(id: SecureRandom.uuid, active_job_id: SecureRandom.uuid, queue_name: 'default',
                           job_class: 'ShowcaseThumbnailRestoreJob', performed_at:, serialized_params: { 'tenant' => tenant })
    end
    waiting = restore.call('ellison-uuid')
    running = restore.call('ellison-uuid', Time.current)
    other = restore.call('meridian-uuid')

    described_class.perform_now

    expect(GoodJob::Job.where(id: [waiting.id, running.id, other.id]).pluck(:id)).to contain_exactly(running.id, other.id)
  end
end
