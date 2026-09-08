# frozen_string_literal: true
namespace :hyku do
  desc "Destroy stale guest users (guest: true, updated_at older than OLDER_THAN_DAYS) in throttled batches. " \
       "ENV: OLDER_THAN_DAYS (default 7), BATCH_SIZE (default 500), BATCH_SLEEP_SECONDS (default 1), DRY_RUN (default false)"
  task prune_stale_guest_users: :environment do
    older_than_days = ENV.fetch('OLDER_THAN_DAYS', 7).to_i
    batch_size = ENV.fetch('BATCH_SIZE', 500).to_i
    batch_sleep_seconds = ENV.fetch('BATCH_SLEEP_SECONDS', 1).to_f
    dry_run = ActiveModel::Type::Boolean.new.cast(ENV.fetch('DRY_RUN', false))

    cutoff = older_than_days.days.ago
    scope = User.unscoped.where(guest: true).where('updated_at < ?', cutoff)

    total = scope.count
    Rails.logger.info("hyku:prune_stale_guest_users - #{total} stale guest users found (guest: true, updated_at < #{cutoff}).")

    if dry_run
      Rails.logger.info('hyku:prune_stale_guest_users - DRY_RUN set, not destroying anything.')
      next
    end

    destroyed = 0
    loop do
      batch = scope.order(:id).limit(batch_size).to_a
      break if batch.empty?

      batch.each(&:destroy)
      destroyed += batch.size
      Rails.logger.info("hyku:prune_stale_guest_users - destroyed #{destroyed}/#{total}...")
      sleep batch_sleep_seconds
    end

    Rails.logger.info("hyku:prune_stale_guest_users - done, destroyed #{destroyed} stale guest users.")
  end
end
