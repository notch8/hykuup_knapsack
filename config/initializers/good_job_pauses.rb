# frozen_string_literal: true

# OVERRIDE GoodJob 4.12.0 config.good_job.enable_pauses: let ops pause a job class, queue, or label from the dashboard without a deploy.
#   Remove once samvera/hyku#3549 is released.
Rails.application.config.good_job.enable_pauses = true if ENV.fetch('HYRAX_ACTIVE_JOB_QUEUE', 'sidekiq') == 'good_job'
