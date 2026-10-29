# frozen_string_literal: true

# A HykuUP showcase tenant as the proprietor Showcases page shows it.
class ShowcaseTenant
  RESTORE_JOB = 'ShowcaseThumbnailRestoreJob'

  attr_reader :account

  delegate :id, :to_param, :name, :cname, :tenant, :last_reset_at, to: :account

  def self.scope
    Account.where(name: DemoTenantResetServiceShowcaseDecorator::SHOWCASE_TENANTS)
  end

  def self.all
    scope.order(:name).map { |account| new(account) }
  end

  def self.find(id)
    new(scope.find(id))
  end

  def initialize(account)
    @account = account
  end

  def look_saved_at
    captured_at = account.demo_tenant_snapshot&.dig('captured_at')
    Time.zone.parse(captured_at) if captured_at
  end

  def saving_or_resetting?
    unfinished(%w[ShowcaseResetJob ShowcaseSnapshotJob])
  end

  # Saving now would capture the automatic video thumbnails instead of the chosen ones.
  def restoring_thumbnails?
    unfinished(RESTORE_JOB)
  end

  # A successful reset stamps last_reset_at after its job starts; one that started later and
  # finished without stamping it gave up, and its error is in Sentry.
  def reset_failed?
    started = jobs('ShowcaseResetJob').where.not(finished_at: nil).maximum(:performed_at)
    started.present? && (last_reset_at.nil? || started > last_reset_at)
  end

  private

  def unfinished(job_class)
    jobs(job_class).where(finished_at: nil).exists?
  end

  def jobs(job_class)
    GoodJob::Job.where(job_class:).where("serialized_params->>'tenant' = ?", tenant)
  end
end
