# frozen_string_literal: true

module HykuKnapsack
  # Links a work's audio and video to its VTT captions as files are ingested, which a
  # Bulkrax import (a demo reset's included) cannot do itself. Adapted from notch8/utk_knapsack#401.
  class CaptionsListener
    include Hyrax::Lockable

    CAPTION_TYPE = 'text/vtt'

    # Each ingest publishes this with its file set once file_ids are saved; earlier,
    # the ingest would save over a link with the copy it loaded first.
    def on_object_membership_updated(event)
      resource = event[:object]
      if resource.try(:file_set?)
        file_set_saved(resource) if caption_or_media?(resource)
      elsif resource.try(:work?)
        locked(resource) { link_unlinked(resource) }
      end
    rescue StandardError => e
      Hyrax.logger.error("#{self.class} could not link captions for #{resource&.id}: #{e.class} #{e.message}")
    end

    private

    def file_set_saved(file_set)
      work = Hyrax.custom_queries.find_parent_work(resource: file_set)
      locked(work) { link(file_set.id, work) } if work
    end

    # Sibling captions ingest concurrently, and each saves the same media file sets.
    def locked(work, &)
      acquire_lock_for("captions-#{work.id}") { ActiveRecord::Base.uncached(&) }
    end

    def ingested_children(work)
      Hyrax.custom_queries.find_child_file_sets(resource: work).select { |fs| fs.file_ids.present? }
    end

    # Only pairs with the file set just saved. A media file's derivatives fire this too, relinking its captions,
    # and its index is refreshed in case Hyrax indexed a copy loaded before a caption was linked.
    def link(saved_id, work)
      siblings = ingested_children(work)
      saved = siblings.find { |fs| fs.id == saved_id }
      return unless saved
      return siblings.select { |fs| media?(fs) }.each { |fs| add_transcripts(fs, [saved_id.to_s]) } if caption?(saved)

      captions = siblings.select { |fs| caption?(fs) }.map { |fs| fs.id.to_s }
      add_transcripts(saved, captions) || (captions.any? && reindex(saved))
    end

    # Files ingested before Bulkrax attached them to the work. Skipped once any link exists,
    # so captions someone unlinked by hand stay unlinked.
    def link_unlinked(work)
      children = ingested_children(work)
      media = children.select { |fs| media?(fs) }
      return if media.any? { |fs| Array(fs.try(:transcript_ids)).any? }

      captions = children.select { |fs| caption?(fs) }.map { |fs| fs.id.to_s }
      media.each { |fs| add_transcripts(fs, captions) } if captions.any?
    end

    # true when it saved the file set
    def add_transcripts(file_set, caption_ids)
      return false unless file_set.respond_to?(:transcript_ids=)

      linked = Array(file_set.transcript_ids).map(&:to_s)
      return false if (caption_ids - linked).empty?

      file_set.transcript_ids = linked | caption_ids
      Hyrax.persister.save(resource: file_set)
      reindex(file_set)
    end

    # A job, so a failed Solr write retries; a later event sees the link saved and skips it.
    def reindex(file_set)
      ReindexItemJob.perform_later(file_set.id.to_s)
      true
    end

    def caption_or_media?(file_set)
      caption?(file_set) || media?(file_set)
    end

    # Ingest sets the label to the original file name; characterization may not have run yet.
    def type_of(file_set)
      Marcel::MimeType.for(name: Array(file_set.label).first.to_s)
    end

    def caption?(file_set)
      type_of(file_set) == CAPTION_TYPE
    end

    def media?(file_set)
      type_of(file_set).match?(%r{\A(audio|video)/})
    end
  end
end
