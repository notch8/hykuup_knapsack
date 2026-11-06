# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Bulkrax::CreateRelationshipsJobDecorator do
  subject(:job) { Bulkrax::CreateRelationshipsJob.new.tap { |j| j.user = user } }

  let(:user) { ::User.system_user }
  let(:work) { Hyrax.persister.save(resource: MobiusWork.new(title: ['parent'])) }
  let(:file_set) { Hyrax.persister.save(resource: Hyrax::FileSet.new(title: ['page'])) }
  let(:other_file_set) { Hyrax.persister.save(resource: Hyrax::FileSet.new(title: ['other'])) }
  let(:fixture_path) { HykuKnapsack::Engine.root.join('spec', 'fixtures', 'files', 'malformed.pdf') }
  let(:ability) { instance_double(Ability, authorize!: true) }
  let!(:upload) { Hyrax::UploadedFile.create!(file: File.open(fixture_path), user:, file_set_uri: file_set.id.to_s) }

  def reloaded_work
    Hyrax.query_service.find_by(id: work.id)
  end

  def save_work(**attributes)
    attributes.each { |attribute, value| work.public_send("#{attribute}=", value) }
    Hyrax.persister.save(resource: work)
  end

  before { seed_flexible_schema_for('MobiusWork') }
  # The suite does not clean Solr, and indexed MobiusWorks block other specs' profiles
  after { Hyrax::SolrService.wipe! }

  def held_uploads
    job.send(:held_ingests).flat_map(&:last)
  end

  describe '#add_to_work' do
    let(:relationship) { instance_double(Bulkrax::PendingRelationship, child_id: 'fs-entry', destroy: true) }

    def add_to_work(parent_record: work)
      job.send(:add_to_work, relationship:, parent_record:, ability:)
    end

    before { allow(job).to receive(:find_record).with('fs-entry', anything).and_return([nil, file_set]) }

    it 'attaches the file set and holds its ingest and relationship for the end of the pass' do
      expect { add_to_work }.not_to have_enqueued_job(ValkyrieIngestJob)
      expect(reloaded_work.member_ids).to eq [file_set.id]
      expect(held_uploads).to eq [upload]
      expect(relationship).not_to have_received(:destroy)
    end

    context 'when the file set is already a member, as when its row is re-imported' do
      it 'holds the ingest a killed pass attached but never queued' do
        save_work(member_ids: [file_set.id])
        add_to_work

        expect(held_uploads).to eq [upload]
      end

      it 'returns the work as saved, not the copy the pass started with' do
        started_with = reloaded_work
        save_work(member_ids: [file_set.id, other_file_set.id])

        expect(add_to_work(parent_record: started_with).member_ids).to eq [file_set.id, other_file_set.id]
      end
    end

    it 'holds no ingest for a file set that already has its files' do
      file_set.file_ids = [Valkyrie::ID.new('ingested-file')]
      add_to_work

      expect(held_uploads).to be_empty
    end
  end

  describe '#process_parent_as_work' do
    let(:importer) do
      Bulkrax::Importer.create!(name: 'probe', admin_set_id: 'admin-set', parser_klass: 'Bulkrax::CsvParser', user:)
    end
    let(:run) { Bulkrax::ImporterRun.create!(importer:) }

    def relate(child_id, order: 0)
      Bulkrax::PendingRelationship.create!(importer_run_id: run.id, parent_id: work.id.to_s, child_id:, order:)
    end

    let(:child_work) { Hyrax.persister.save(resource: MobiusWork.new(title: ['child'])) }

    def process(pass = job)
      pass.send(:process_parent_as_work, parent_record: work, parent_identifier: work.id.to_s)
    end

    def prepare(pass)
      allow(pass).to receive(:find_record).with('fs-entry', anything).and_return([nil, file_set])
      allow(pass).to receive(:find_record).with('other-entry', anything).and_return([nil, other_file_set])
      allow(pass).to receive(:find_record).with('child-entry', anything).and_return([nil, child_work])
      pass.importer_run_id = run.id
      pass.ability = ability
      pass.number_of_successes = 0
      pass.number_of_failures = 0
      pass.errors = []
      pass
    end

    before do
      prepare(job)
      allow(ValkyrieIngestJob).to receive(:perform_later).and_return(true)
    end

    it 'queues the held ingest once the work is saved with its thumbnail, so characterization cannot overwrite the pass' do
      relate('fs-entry')
      thumbnail_when_queued = nil
      allow(ValkyrieIngestJob).to receive(:perform_later) { thumbnail_when_queued = reloaded_work.thumbnail_id }

      process

      expect(ValkyrieIngestJob).to have_received(:perform_later).with(upload).once
      expect(thumbnail_when_queued).to eq file_set.id
    end

    it 'queues the held ingest while holding the work lock, so a second pass cannot queue it again' do
      relate('fs-entry')
      locked = false
      queued_while_locked = nil
      allow(job).to receive(:conditionally_acquire_lock_for) do |_key, &block|
        locked = true
        block.call
      ensure
        locked = false
      end
      allow(ValkyrieIngestJob).to receive(:perform_later) { queued_while_locked = locked }

      process

      expect(queued_while_locked).to be true
    end

    it 'deletes the relationship only after its ingest is queued' do
      relationship = relate('fs-entry')
      kept_when_queued = nil
      allow(ValkyrieIngestJob).to receive(:perform_later) { kept_when_queued = Bulkrax::PendingRelationship.exists?(relationship.id) }

      process

      expect(kept_when_queued).to be true
      expect(Bulkrax::PendingRelationship.exists?(relationship.id)).to be false
    end

    it 'leaves the relationship for the next pass when the worker dies before queueing' do
      relationship = relate('fs-entry')
      allow(job).to receive(:queue_held_ingests)

      process

      expect(reloaded_work.member_ids).to eq [file_set.id]
      expect(Bulkrax::PendingRelationship.exists?(relationship.id)).to be true
    end

    it 'records the error, queues nothing and keeps the relationship for the rescheduled pass when saving the work fails' do
      relationship = relate('fs-entry')
      allow(Bulkrax.object_factory).to receive(:save!).and_raise('save failed')

      process

      expect(job.errors.map(&:message)).to include('save failed')
      expect(ValkyrieIngestJob).not_to have_received(:perform_later)
      expect(relationship.reload.status_message).to eq 'save failed'
    end

    it 'keeps a child work\'s relationship too when saving the work fails, and the retry finishes the pass' do
      relationships = [relate('fs-entry'), relate('child-entry')]
      allow(Bulkrax.object_factory).to receive(:save!).and_raise('save failed')
      process
      expect(relationships.map { |rel| rel.reload.status_message }).to eq ['save failed', 'save failed']

      allow(Bulkrax.object_factory).to receive(:save!).and_call_original
      retry_pass = prepare(Bulkrax::CreateRelationshipsJob.new.tap { |j| j.user = user })
      process(retry_pass)

      expect(retry_pass.errors).to be_empty
      expect(reloaded_work.member_ids).to eq [file_set.id, child_work.id]
      expect(Bulkrax::PendingRelationship.where(id: relationships.map(&:id))).to be_empty
    end

    it 'records the error and keeps the relationship when the ingest is refused without raising' do
      relationship = relate('fs-entry')
      allow(ValkyrieIngestJob).to receive(:perform_later).and_return(false)

      process

      expect(job.errors.map(&:message).join).to match(/Could not queue ingest/)
      expect(relationship.reload.status_message).to match(/Could not queue ingest/)
    end

    it 'marks only the relationships it has not released when a later ingest is refused' do
      queued = relate('fs-entry', order: 1)
      refused = relate('other-entry', order: 2)
      other_upload = Hyrax::UploadedFile.create!(file: File.open(fixture_path), user:, file_set_uri: other_file_set.id.to_s)
      allow(ValkyrieIngestJob).to receive(:perform_later).with(other_upload).and_return(false)

      process

      expect(Bulkrax::PendingRelationship.exists?(queued.id)).to be false
      expect(refused.reload.status_message).to match(/Could not queue ingest/)
    end

    it 'attaches in row order, not the order the rows finished' do
      relate('other-entry', order: 2)
      relate('fs-entry', order: 1)

      process

      expect(reloaded_work.member_ids).to eq [file_set.id, other_file_set.id]
    end

    it 'keeps the listed order for children named in one cell, which share an order' do
      relate('fs-entry', order: 1)
      relate('other-entry', order: 1)

      process

      expect(reloaded_work.member_ids).to eq [file_set.id, other_file_set.id]
    end

    it 'ingests once when both the work row and the file set row name the relationship' do
      2.times { relate('fs-entry') }

      process

      expect(ValkyrieIngestJob).to have_received(:perform_later).with(upload).once
    end
  end

  describe '#fill_in_representative_and_thumbnail' do
    it 'sets both to the first file set when the work has neither' do
      save_work(member_ids: [file_set.id, other_file_set.id])

      job.send(:fill_in_representative_and_thumbnail, work.id)

      expect([reloaded_work.representative_id, reloaded_work.thumbnail_id]).to eq [file_set.id, file_set.id]
    end

    it 'keeps a representative the work already has' do
      save_work(member_ids: [file_set.id, other_file_set.id], representative_id: other_file_set.id)

      job.send(:fill_in_representative_and_thumbnail, work.id)

      expect([reloaded_work.representative_id, reloaded_work.thumbnail_id]).to eq [other_file_set.id, file_set.id]
    end
  end
end
