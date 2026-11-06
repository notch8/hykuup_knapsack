# frozen_string_literal: true

require 'rails_helper'

# Mirrors the upstream spec for samvera/bulkrax#1260, calling #reimport directly
# because the knapsack does not load Bulkrax's factories.
RSpec.describe Bulkrax::DeleteAndImportJobDecorator, type: :job do
  let(:importer) do
    Bulkrax::Importer.create!(name: 'probe', admin_set_id: 'admin-set', parser_klass: 'Bulkrax::CsvParser', user: ::User.system_user)
  end
  let(:run) { importer.importer_runs.create! }
  let(:entry) { Bulkrax::CsvEntry.create!(identifier: 'rerun', importerexporter: importer) }

  before { entry.set_status_info('Deleted', run) }

  [Bulkrax::DeleteAndImportWorkJob, Bulkrax::DeleteAndImportCollectionJob, Bulkrax::DeleteAndImportFileSetJob].each do |job_class|
    it "shows the entry as Pending while #{job_class.name.demodulize} re-imports it, so relationships wait for it" do
      status_during_import = nil
      allow(job_class::IMPORT_CLASS).to receive(:perform_now) { status_during_import = Bulkrax::Entry.find(entry.id).status_message }

      job_class.new.reimport(entry, run)

      expect(status_during_import).to eq 'Pending'
    end
  end
end
