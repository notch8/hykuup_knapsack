# frozen_string_literal: true

# OVERRIDE Bulkrax v9.5.1 Bulkrax::DeleteAndImportJob#reimport to set the entry
# back to Pending first, so ScheduleRelationshipsJob waits for the re-import
# instead of counting the delete's Deleted status as finished. Part of the
# samvera/bulkrax#1260 port; see ScheduleRelationshipsJobDecorator.
module Bulkrax
  module DeleteAndImportJobDecorator
    def reimport(entry, importer_run)
      Bulkrax::Entry.find(entry.id).set_status_info('Pending', importer_run)
      super
    end
  end
end

Bulkrax::DeleteAndImportJob.prepend(Bulkrax::DeleteAndImportJobDecorator)
