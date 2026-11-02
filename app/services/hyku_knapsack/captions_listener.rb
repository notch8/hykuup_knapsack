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
      file_set = event[:object]
      return unless file_set.try(:file_set?) && caption_or_media?(file_set)

      work = Hyrax.custom_queries.find_parent_work(resource: file_set)
      # Sibling captions ingest concurrently, and each saves the same media file sets.
      acquire_lock_for("captions-#{work.id}") { link(file_set.id, work) } if work
    rescue StandardError => e
      Hyrax.logger.error("#{self.class} could not link captions for #{file_set&.id}: #{e.class} #{e.message}")
    end

    private

    # Only pairs with the file set just saved. A media file's derivatives fire this too, relinking its captions,
    # which also restores a link a derivative save wrote over.
    def link(ingested_id, work)
      ActiveRecord::Base.uncached do
        siblings = Hyrax.custom_queries.find_child_file_sets(resource: work).select { |fs| fs.file_ids.present? }
        ingested = siblings.find { |fs| fs.id == ingested_id }
        next unless ingested
        next siblings.select { |fs| media?(fs) }.each { |fs| add_transcripts(fs, [ingested_id.to_s]) } if caption?(ingested)

        add_transcripts(ingested, siblings.select { |fs| caption?(fs) }.map { |fs| fs.id.to_s })
      end
    end

    def add_transcripts(file_set, caption_ids)
      return unless file_set.respond_to?(:transcript_ids=)

      linked = Array(file_set.transcript_ids).map(&:to_s)
      return if (caption_ids - linked).empty?

      file_set.transcript_ids = linked | caption_ids
      Hyrax.index_adapter.save(resource: Hyrax.persister.save(resource: file_set))
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
