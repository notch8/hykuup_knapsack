# frozen_string_literal: true

RSpec.describe ShowcaseTenant do
  subject(:showcase) { described_class.new(account) }

  let(:account) { FactoryBot.build(:account, name: 'meridian', tenant: 'meridian-uuid', last_reset_at:) }
  let(:last_reset_at) { Time.zone.parse('2026-10-28 23:00') }

  def job(job_class, finished_at: nil, performed_at: nil, tenant: 'meridian-uuid')
    GoodJob::Job.create!(id: SecureRandom.uuid, active_job_id: SecureRandom.uuid, queue_name: 'default',
                         job_class:, finished_at:, performed_at:, serialized_params: { 'tenant' => tenant })
  end

  describe '#saving_or_resetting?' do
    it 'is true while a reset or save is unfinished' do
      job('ShowcaseSnapshotJob')
      expect(showcase).to be_saving_or_resetting
    end

    it 'ignores finished jobs, other tenants and the thumbnail restore' do
      job('ShowcaseResetJob', finished_at: Time.current)
      job('ShowcaseResetJob', tenant: 'ellison-uuid')
      job('ShowcaseThumbnailRestoreJob')
      expect(showcase).not_to be_saving_or_resetting
    end
  end

  describe '#restoring_thumbnails?' do
    it 'is true while the thumbnail restore is unfinished' do
      job('ShowcaseThumbnailRestoreJob')
      expect(showcase).to be_restoring_thumbnails
    end
  end

  describe '#reset_failed?' do
    it 'is true when a reset started after the last successful one and finished without stamping it' do
      job('ShowcaseResetJob', performed_at: last_reset_at + 1.day, finished_at: last_reset_at + 1.day + 1.hour)
      expect(showcase).to be_reset_failed
    end

    it 'is false after a successful reset, whose job finishes just after the stamp' do
      job('ShowcaseResetJob', performed_at: last_reset_at - 30.minutes, finished_at: last_reset_at + 1.second)
      expect(showcase).not_to be_reset_failed
    end

    it 'ignores a reset that is still running' do
      job('ShowcaseResetJob', performed_at: last_reset_at + 1.day)
      expect(showcase).not_to be_reset_failed
    end
  end

  it 'reads when the look was saved from the snapshot' do
    account.demo_tenant_snapshot = { 'captured_at' => '2026-10-28T23:10:05Z' }
    expect(showcase.look_saved_at).to eq Time.zone.parse('2026-10-28T23:10:05Z')
  end

  describe '.operator?' do
    it 'is true only for the listed emails, in any case' do
      expect(described_class.operator?(User.new(email: 'Nick@Notch8.com'))).to be true
      expect(described_class.operator?(User.new(email: 'someone@notch8.com'))).to be false
      expect(described_class.operator?(nil)).to be false
    end
  end
end
