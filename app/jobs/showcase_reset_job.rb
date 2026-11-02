# frozen_string_literal: true

# Resets a HykuUP showcase tenant once, from the proprietor Showcases page.
# Unlike the nightly sandbox job, it schedules no next run.
class ShowcaseResetJob < DemoTenantResetJob
  def perform
    drop_waiting_thumbnail_restores!
    DemoTenantResetService.new(account: current_account, **service_options).reset!
  end

  private

  # A waiting restore could reindex a work after the wipe; the reset queues its own.
  def drop_waiting_thumbnail_restores!
    GoodJob::Job.where(job_class: 'ShowcaseThumbnailRestoreJob', finished_at: nil, performed_at: nil)
                .where("serialized_params->>'tenant' = ?", current_account.tenant)
                .destroy_all
  end
end
