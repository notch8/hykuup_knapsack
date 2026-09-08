# frozen_string_literal: true
namespace :hyku do
  desc "Destroy old anonymous (unsaved) Blacklight searches (created_at older than OLDER_THAN_DAYS, user_id IS NULL) " \
       "in throttled batches, across all tenants. Real searches saved by a user (user_id present) are never touched " \
       "- see Search#saved? in the blacklight gem. " \
       "ENV: OLDER_THAN_DAYS (default 30), BATCH_SIZE (default 5000), BATCH_SLEEP_SECONDS (default 1), DRY_RUN (default false)"
  task prune_old_searches: :environment do
    older_than_days = ENV.fetch('OLDER_THAN_DAYS', 30).to_i
    batch_size = ENV.fetch('BATCH_SIZE', 5_000).to_i
    batch_sleep_seconds = ENV.fetch('BATCH_SLEEP_SECONDS', 1).to_f
    dry_run = ActiveModel::Type::Boolean.new.cast(ENV.fetch('DRY_RUN', false))

    cutoff = older_than_days.days.ago
    total_destroyed = 0

    Account.find_each do |account|
      Apartment::Tenant.switch!(account.tenant)

      scope = Search.where('created_at < ? AND user_id IS NULL', cutoff)
      tenant_total = scope.count
      next if tenant_total.zero?

      Rails.logger.info("hyku:prune_old_searches - #{account.cname}: #{tenant_total} old anonymous searches found.")
      next if dry_run

      tenant_destroyed = 0
      scope.in_batches(of: batch_size) do |relation|
        batch_count = relation.delete_all
        tenant_destroyed += batch_count
        total_destroyed += batch_count
        Rails.logger.info("hyku:prune_old_searches - #{account.cname}: destroyed #{tenant_destroyed}/#{tenant_total}...")
        sleep batch_sleep_seconds
      end
    end

    Rails.logger.info("hyku:prune_old_searches - done, destroyed #{total_destroyed} old anonymous searches across all tenants.")
  end
end
