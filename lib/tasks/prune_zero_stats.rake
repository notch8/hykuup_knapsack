# frozen_string_literal: true
# rubocop:disable Metrics/BlockLength
namespace :hyku do
  desc "Delete redundant zero-count rows from the stats cache tables (FileViewStat, FileDownloadStat, " \
       "WorkViewStat), across all tenants - wraps Hyrax::StatsPruner (samvera/hyrax#7649), which has no " \
       "concept of Apartment tenants on its own. ENV: BATCH_SIZE (default 50000), DRY_RUN (default false)"
  task prune_zero_stats: :environment do
    dry_run = ActiveModel::Type::Boolean.new.cast(ENV.fetch('DRY_RUN', false))
    batch_size = ENV.fetch('BATCH_SIZE', 50_000).to_i

    Account.find_each do |account|
      Apartment::Tenant.switch!(account.tenant)

      { FileViewStat => :file_id, FileDownloadStat => :file_id, WorkViewStat => :work_id }.each do |klass, id_column|
        Rails.logger.info("hyku:prune_zero_stats - #{account.cname}: pruning #{klass}...")
        Hyrax::StatsPruner.call(klass:, id_column:, dry_run:, batch_size:)
      end
    rescue StandardError => e
      Rails.logger.error("hyku:prune_zero_stats - #{account.cname} failed: #{e.message}")
    end
  end
end
# rubocop:enable Metrics/BlockLength
