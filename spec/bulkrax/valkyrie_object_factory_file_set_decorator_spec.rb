# frozen_string_literal: true

require 'rails_helper'

# Lives outside spec/factories, which FactoryBot loads as definitions.
RSpec.describe Bulkrax::ValkyrieObjectFactoryFileSetDecorator do
  let(:user) { ::User.system_user }
  let(:fixture_path) { HykuKnapsack::Engine.root.join('spec', 'fixtures', 'files', 'malformed.pdf') }
  let(:work) { Hyrax.persister.save(resource: MobiusWork.new(title: ['parent'], depositor: user.user_key)) }

  def build_factory(title, visibility: nil, files: 1, id: nil, **extra)
    attributes = { 'title' => [title], 'parents' => [work.id.to_s], 'file' => [fixture_path.to_s] * files,
                   'visibility' => visibility, 'bulkrax_identifier' => [title], 'id' => id }.compact.merge(extra.stringify_keys)
    Bulkrax::ValkyrieObjectFactory.new(attributes:,
                                       source_identifier_value: title,
                                       work_identifier: 'bulkrax_identifier',
                                       work_identifier_search_field: 'bulkrax_identifier_tesim',
                                       related_parents_parsed_mapping: 'parents',
                                       replace_files: false,
                                       user:,
                                       klass: Hyrax::FileSet,
                                       importer_run_id: nil,
                                       update_files: false).tap do |factory|
      allow(factory).to receive(:find_record) { [nil, Hyrax.query_service.find_by(id: work.id)] }
    end
  end

  def create_file_set(title, upload = uploaded_file, visibility: nil)
    build_factory(title, visibility:).send(:create_file_set, uploaded_files: [upload.id])
  end

  def uploaded_file
    Hyrax::UploadedFile.create(file: File.open(fixture_path), user:)
  end

  def reloaded(resource)
    Hyrax.query_service.find_by(id: resource.id)
  end

  def embargo_work(release_date: 1.month.from_now.to_date)
    work.embargo = Hyrax.persister.save(resource: Hyrax::Embargo.new(embargo_release_date: release_date,
                                                                     visibility_during_embargo: 'restricted',
                                                                     visibility_after_embargo: 'open'))
    Hyrax::EmbargoManager.apply_embargo_for(resource: work)
    work.permission_manager.acl.save
    Hyrax.persister.save(resource: work)
  end

  before { seed_flexible_schema_for('MobiusWork') }
  # The suite does not clean Solr, and indexed MobiusWorks block other specs' profiles
  after { Hyrax::SolrService.wipe! }

  it 'creates the file set and leaves the work untouched' do
    file_set = create_file_set('first')

    expect(file_set).to be_a(Hyrax::FileSet).and(be_persisted)
    expect(file_set.title).to eq ['first']
    expect(reloaded(work).member_ids).to be_empty
  end

  it 'leaves the ingest for the relationship pass' do
    expect { create_file_set('first') }.not_to have_enqueued_job(ValkyrieIngestJob)
  end

  context 'with a visibility on the row' do
    it "gives the file set that visibility rather than the work's" do
      file_set = create_file_set('first', visibility: 'open')

      expect(reloaded(work).visibility).to eq 'restricted'
      expect(reloaded(file_set).visibility).to eq 'open'
    end

    it "does not copy down the work's embargo" do
      embargo_work
      file_set = create_file_set('first', visibility: 'open')

      expect(reloaded(file_set).embargo).to be_nil
      expect(reloaded(file_set).visibility).to eq 'open'
    end
  end

  context 'without a visibility on the row' do
    it "inherits the work's visibility" do
      work.visibility = 'authenticated'
      work.permission_manager.acl.save

      expect(reloaded(create_file_set('first')).visibility).to eq 'authenticated'
    end

    it "inherits the work's embargo" do
      release_date = 1.month.from_now.to_date
      embargo_work(release_date:)

      file_set = reloaded(create_file_set('first'))

      expect(file_set.embargo.embargo_release_date.to_date).to eq release_date
      expect(file_set.visibility).to eq 'restricted'
    end

    it "treats an embargo visibility, which only the work can carry, as none and inherits the work's embargo" do
      embargo_work
      file_set = reloaded(create_file_set('first', visibility: 'embargo'))

      expect(file_set.embargo).to be_present
      expect(file_set.visibility).to eq 'restricted'
    end

    it "inherits the work's lease" do
      work.lease = Hyrax.persister.save(resource: Hyrax::Lease.new(lease_expiration_date: 1.month.from_now.to_date,
                                                                   visibility_during_lease: 'open',
                                                                   visibility_after_lease: 'restricted'))
      Hyrax::LeaseManager.apply_lease_for(resource: work)
      work.permission_manager.acl.save
      Hyrax.persister.save(resource: work)

      file_set = reloaded(create_file_set('first'))

      expect(file_set.lease.visibility_after_lease).to eq 'restricted'
      expect(file_set.visibility).to eq 'open'
    end
  end

  context 'when the row is re-imported after the work\'s visibility changed' do
    def reimport(file_set, visibility: nil, **extra)
      work.visibility = 'open'
      work.permission_manager.acl.save
      build_factory('first', visibility:, id: file_set.id.to_s, **extra).run
      reloaded(file_set).visibility
    end

    it "inherits the work's new visibility when the row has none" do
      expect(reimport(create_file_set('first'))).to eq 'open'
    end

    it "keeps the row's visibility when it has one" do
      expect(reimport(create_file_set('first'), visibility: 'authenticated')).to eq 'authenticated'
    end

    it "leaves a file set under its own embargo restricted when the row has no visibility" do
      file_set = create_file_set('first')
      embargo = Hyrax.persister.save(resource: Hyrax::Embargo.new(embargo_release_date: 1.year.from_now,
                                                                  visibility_during_embargo: 'restricted',
                                                                  visibility_after_embargo: 'open'))
      file_set.embargo_id = embargo.id
      file_set.visibility = 'restricted'
      file_set.permission_manager.acl.save
      Hyrax.persister.save(resource: file_set)

      expect(reimport(file_set)).to eq 'restricted'
    end

    it "keeps the row's own embargo rather than opening the file set to the work's visibility" do
      visibility = reimport(create_file_set('first'), visibility: 'embargo', embargo_release_date: 1.year.from_now.to_date.to_s,
                                                      visibility_during_embargo: 'restricted', visibility_after_embargo: 'open')

      expect(visibility).to eq 'restricted'
    end
  end

  it 'fails a row whose parent work cannot be found without creating anything' do
    upload = uploaded_file
    factory = build_factory('first')
    allow(factory).to receive(:find_record).and_return([nil, nil])

    expect { factory.send(:create_file_set, uploaded_files: [upload.id]) }
      .to raise_error(StandardError, "first has no parent work #{work.id} to attach to")
    expect(Hyrax.query_service.find_all_of_model(model: Hyrax::FileSet).to_a).to be_empty
    expect(upload.reload.file_set_uri).to be_nil
  end

  it 'fails a row whose parent is not a work without creating anything' do
    upload = uploaded_file
    factory = build_factory('first')
    allow(factory).to receive(:find_record).and_return([nil, Hyrax::PcdmCollection.new(title: ['shelf'])])

    expect { factory.send(:create_file_set, uploaded_files: [upload.id]) }
      .to raise_error(StandardError, "first names #{work.id} as its parent, which is not a work")
    expect(Hyrax.query_service.find_all_of_model(model: Hyrax::FileSet).to_a).to be_empty
    expect(upload.reload.file_set_uri).to be_nil
  end

  it 'fails a re-imported row whose parent is not a work before updating it' do
    file_set = create_file_set('first')
    factory = build_factory('renamed', visibility: 'open', id: file_set.id.to_s)
    allow(factory).to receive(:find_record).and_return([nil, Hyrax::PcdmCollection.new(title: ['shelf'])])

    expect { factory.run }.to raise_error(StandardError, "renamed names #{work.id} as its parent, which is not a work")
    expect(reloaded(file_set).title).to eq ['first']
  end

  it 'fails a row with more than one file without creating anything' do
    factory = build_factory('first', files: 2)

    expect { factory.send(:create_file_set, uploaded_files: [uploaded_file.id, uploaded_file.id]) }
      .to raise_error(StandardError, 'first lists 2 files; a file set row takes one')
    expect(Hyrax.query_service.find_all_of_model(model: Hyrax::FileSet).to_a).to be_empty
  end

  it 'fails the entry when there is no file to attach' do
    upload = uploaded_file
    upload.update!(file_set_uri: 'already-attached')

    expect { create_file_set('first', upload) }.to raise_error(StandardError, 'first has no file to attach')
  end

  # Threads need committed rows, hence truncation.
  describe 'file sets imported at once for one work', :truncation do
    let(:titles) { %w[first second third] }
    let(:importer) do
      Bulkrax::Importer.create!(name: 'probe', admin_set_id: 'admin-set', parser_klass: 'Bulkrax::CsvParser', user:,
                                field_mapping: Bulkrax.field_mappings['Bulkrax::CsvParser'])
    end

    def create_at_once
      %i[admin_group editors_group depositors_group].each { |group| FactoryBot.create(group) }
      Hyrax::AdminSetCreateService.find_or_create_default_admin_set
      rows = titles.map { |title| [build_factory(title), uploaded_file] }

      rows.map do |factory, upload|
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            factory.send(:create_file_set, uploaded_files: [upload.id])
          end
        end
      end.each(&:join)
    end

    # Upstream create_file_set saves the work, so the empty check fails if it comes back;
    # the relationships job would re-add any member the threads dropped.
    it 'leaves the work alone, then puts every file set in it, in row order, once their entries are related' do
      run = Bulkrax::ImporterRun.create!(importer:)
      create_at_once
      expect(reloaded(work).member_ids).to be_empty

      titles.each do |title|
        Bulkrax::CsvFileSetEntry.create!(identifier: title, importerexporter: importer,
                                         parsed_metadata: { 'parents' => [work.id.to_s] }).parent_jobs
      end

      Bulkrax::CreateRelationshipsJob.perform_now(parent_identifier: work.id.to_s, importer_run_id: run.id,
                                                  run_user: create(:superadmin))

      members = Hyrax.query_service.find_members(resource: reloaded(work)).map { |member| member.title.first }
      expect(members).to eq titles
    end
  end
end
