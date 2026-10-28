# frozen_string_literal: true

# Puts a showcase tenant's saved video thumbnails back after a demo reset.
# A video's processing writes its thumbnail first and mp4 last, and a retried
# job writes the thumbnail again, so each work is rechecked until its mp4 exists.
class ShowcaseThumbnailRestoreJob < ApplicationJob
  RECHECK_WAIT = 30.minutes
  MAX_CHECKS = 96

  def perform(entries, checks = 1)
    works = Hyku::Application.work_types.flat_map { |model| Hyrax.query_service.find_all_of_model(model:).to_a }
                             .index_by { |work| Array(work.try(:bulkrax_identifier)).first || Array(work.try(:source)).first }
    pending = entries.reject { |entry| restore(works[entry['identifier']], entry) }
    return if pending.empty?

    if checks >= MAX_CHECKS
      Rails.logger.warn("[DemoTenantReset] gave up restoring thumbnails for #{pending.map { |e| e['identifier'] }.join(', ')}")
      return
    end

    self.class.set(wait: RECHECK_WAIT).perform_later(pending, checks + 1)
  end

  private

  # true once the entry needs no more checks
  def restore(work, entry)
    unless work && File.exist?(entry['file'])
      Rails.logger.warn("[DemoTenantReset] no work or saved thumbnail for #{entry['identifier']}; skipped")
      return true
    end
    return false unless work.try(:thumbnail_id)

    thumbnail = derivative(work, 'thumbnail')
    return false unless File.exist?(thumbnail)

    unless FileUtils.compare_file(entry['file'], thumbnail)
      FileUtils.cp(entry['file'], thumbnail)
      Hyrax.index_adapter.save(resource: work)
    end
    File.exist?(derivative(work, 'mp4'))
  end

  def derivative(work, name)
    Hyrax::DerivativePath.derivative_path_for_reference(work.thumbnail_id.to_s, name)
  end
end
