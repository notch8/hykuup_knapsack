# frozen_string_literal: true

# OVERRIDE Bulkrax v9.5.1 Bulkrax::CsvFileSetEntry
#   - #parent_jobs (from FileSetEntryBehavior): record a pending relationship to
#     the first parent work instead of none, since the knapsack's factory
#     decorator creates file sets unattached and CreateRelationshipsJob attaches
#     them. Only the first, as create_file_set and ImportFileSetJob use only it
#     and each relationship would queue the same upload's ingest again.
#   - #add_visibility (from ImportBehavior): leave a blank visibility blank
#     rather than taking the importer's default, so the file set inherits its
#     work's.
module Bulkrax
  module CsvFileSetEntryDecorator
    def add_visibility
      parsed_metadata.delete('visibility') if parsed_metadata['visibility'].blank?
    end

    def parent_jobs
      parent_identifier = Array(parsed_metadata[related_parents_parsed_mapping]).first
      return if parent_identifier.blank?

      PendingRelationship.create!(child_id: identifier,
                                  parent_id: parent_identifier,
                                  importer_run_id: importerexporter.last_run.id,
                                  order: id)
    end
  end
end

Bulkrax::CsvFileSetEntry.prepend(Bulkrax::CsvFileSetEntryDecorator)
