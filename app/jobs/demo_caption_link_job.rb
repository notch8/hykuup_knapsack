# frozen_string_literal: true

# Points each audio and video file set at the caption file sets of its work
# after a demo reset. The reset returns before file ingest finishes, so works
# still ingesting are rechecked until they settle.
class DemoCaptionLinkJob < ApplicationJob
  RECHECK_WAIT = 10.minutes
  MAX_CHECKS = 288
  CAPTION_TYPE = 'text/vtt'
  CAPTION_TITLE = 'Captions'

  def perform(checks = 1)
    works = Hyku::Application.work_types.flat_map { |model| Hyrax.query_service.find_all_of_model(model:).to_a }
    pending = works.reject { |work| link(work) }
    return if pending.empty?

    if checks >= MAX_CHECKS
      Rails.logger.warn("[DemoTenantReset] files of works #{pending.map { |w| w.id.to_s }.join(', ')} never finished ingesting; their captions are unlinked")
      return
    end

    self.class.set(wait: RECHECK_WAIT).perform_later(checks + 1)
  end

  private

  # true once the work needs no more checks
  def link(work)
    originals = Hyrax.custom_queries.find_child_file_sets(resource: work).index_with { |fs| original_of(fs) }
    # Until ingested a file set has no name, and its ingest saves a copy loaded earlier, undoing any link.
    return false if originals.value?(nil)

    captions, others = originals.keys.partition { |fs| types_of(originals[fs]).include?(CAPTION_TYPE) }
    return true if captions.empty?
    return skip_unsupported(work) unless captions.first.respond_to?(:transcript_ids=)

    media = others.select { |fs| types_of(originals[fs]).any? { |type| type.match?(%r{\A(audio|video)/}) } }
    changed = relink(media, captions.map { |fs| fs.id.to_s }) + retitle(captions)
    bump(work) if changed.positive?
    true
  end

  # Characterization can lag the reset by hours and may call a caption text/plain, so the name counts too.
  def types_of(original)
    [original.mime_type.to_s, Marcel::MimeType.for(name: original.original_filename.to_s)]
  end

  def original_of(file_set)
    Hyrax.custom_queries.find_original_file(file_set:)
  rescue StandardError
    nil
  end

  def relink(media, caption_ids)
    changed = media.reject { |fs| Array(fs.transcript_ids).map(&:to_s).sort == caption_ids.sort }
    changed.each do |fs|
      fs.transcript_ids = caption_ids
      save(fs)
    end
    Rails.logger.info("[DemoTenantReset] linked #{caption_ids.join(', ')} to #{changed.map { |fs| fs.id.to_s }.join(', ')}") if changed.any?
    changed.size
  end

  # Players label a track by its title, which the import leaves as the file name.
  def retitle(captions)
    return 0 unless captions.one? && Array(captions.first.title) == [captions.first.label]

    captions.first.title = [CAPTION_TITLE]
    save(captions.first)
    1
  end

  # Manifests are cached by the work's modified time.
  def bump(work)
    save(Hyrax.query_service.find_by(id: work.id))
  end

  def save(resource)
    Hyrax.index_adapter.save(resource: Hyrax.persister.save(resource:))
  end

  def skip_unsupported(work)
    Rails.logger.warn("[DemoTenantReset] file sets have no transcript_ids; captions of #{work.id} left unlinked")
    true
  end
end
