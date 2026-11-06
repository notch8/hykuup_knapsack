# frozen_string_literal: true

# OVERRIDE Bulkrax v9.5.1 Bulkrax::CreateRelationshipsJob, which now attaches
# imported file sets (see ValkyrieObjectFactoryFileSetDecorator)
#   - #process_parent_as_work: relate in the stored row order, which
#     find_each ignores, so pages attach in CSV order rather than the order
#     their rows finished; then, still holding the work's lock, give the work
#     the representative and thumbnail Hyrax set when it attached the file sets
#     itself, then queue the held ingests, so characterization and derivatives,
#     OCR included, run with a parent and do not save the work while the pass
#     is still saving it, and a second pass cannot queue the same uploads. A
#     failure is recorded as an error, so Bulkrax reschedules the pass, and the
#     relationships not yet released stay for it, marked with the error so
#     ScheduleRelationshipsJob's stalled checks stop retrying them hourly.
#   - #add_to_work: keep every relationship until the pass has saved the work
#     and queued any ingest for the child, so a failed or killed pass retries
#     it; return the work as saved when upstream returns true for a child
#     already a member, or the rest of the pass fails
module Bulkrax
  module CreateRelationshipsJobDecorator
    KeptRelationship = Class.new(SimpleDelegator) { def destroy; end }

    private

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    def process_parent_as_work(parent_record:, parent_identifier:)
      conditionally_acquire_lock_for(parent_record.id.to_s) do
        ActiveRecord::Base.uncached do
          Bulkrax::PendingRelationship.where(parent_id: parent_identifier, importer_run_id: @importer_run_id).ordered.order(:id).each do |rel|
            raise "#{rel} needs a child to create relationship" if rel.child_id.nil?
            raise "#{rel} needs a parent to create relationship" if rel.parent_id.nil?
            parent_record = add_to_work(relationship: rel, parent_record:, ability:)
            self.number_of_successes += 1
            @parent_record_members_added = true
          rescue => e
            rel.update(status_message: e.message)
            @number_of_failures += 1
            @errors << e
          end
        end

        if @parent_record_members_added
          Bulkrax.object_factory.save!(resource: parent_record, user: @user)
          reloaded_parent = Bulkrax.object_factory.find(parent_record.id)
          Bulkrax.object_factory.update_index(resources: [reloaded_parent])
          Bulkrax.object_factory.publish(event: 'object.membership.updated', object: reloaded_parent, user: @user)
          fill_in_representative_and_thumbnail(parent_record.id)
        end
        queue_held_ingests
      end
    rescue => e
      # Bulkrax reschedules on errors; an exception would not be retried under GoodJob
      @number_of_failures += 1
      @errors << e
      held_ingests.each { |relationship, _uploads| relationship.update(status_message: e.message) unless relationship.destroyed? }
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

    def add_to_work(relationship:, parent_record:, ability:)
      updated_parent = super(relationship: KeptRelationship.new(relationship), parent_record:, ability:)
      _child_entry, child_record = find_record(relationship.child_id, @importer_run_id)
      held_ingests << [relationship, pending_uploads(child_record)]
      updated_parent.is_a?(Valkyrie::Resource) ? updated_parent : Hyrax.query_service.find_by(id: parent_record.id)
    end

    def pending_uploads(child_record)
      return [] unless child_record.try(:file_set?) && child_record.file_ids.blank?

      Hyrax::UploadedFile.where(file_set_uri: child_record.id.to_s).to_a
    end

    def queue_held_ingests
      queued = Set.new
      held_ingests.each do |relationship, uploads|
        uploads.each do |upload|
          next unless queued.add?(upload.id)
          ValkyrieIngestJob.perform_later(upload) || raise("Could not queue ingest for upload #{upload.id}")
        end
        relationship.destroy
      end
    end

    def held_ingests
      @held_ingests ||= []
    end

    def fill_in_representative_and_thumbnail(parent_id)
      parent = Hyrax.query_service.find_by(id: parent_id)
      first_file_set_id = Hyrax.custom_queries.find_child_file_set_ids(resource: parent).first
      return if first_file_set_id.nil? || (parent.representative_id.present? && parent.thumbnail_id.present?)

      parent.representative_id = first_file_set_id if parent.representative_id.blank?
      parent.thumbnail_id = first_file_set_id if parent.thumbnail_id.blank?
      Bulkrax.object_factory.save!(resource: parent, user: @user)
    end
  end
end

Bulkrax::CreateRelationshipsJob.prepend(Bulkrax::CreateRelationshipsJobDecorator)
