# frozen_string_literal: true

# Lets ops pause/resume a job class, queue, or label from the GoodJob dashboard
# without a deploy, e.g. DemoTenantResetJob during a maintenance window.
# Remove once samvera/hyku#3549 is released.
if ENV.fetch('HYRAX_ACTIVE_JOB_QUEUE', 'sidekiq') == 'good_job'
  Rails.application.config.good_job.enable_pauses = true
end
