# frozen_string_literal: true

# OVERRIDE Bulkrax v9.5.1 Bulkrax::ValkyrieObjectFactory#create_file_set and #update_file_set
#   - create the file set without saving its parent work. Bulkrax appends each
#     file set to a copy of the work read before any lock, so file sets imported
#     at once for one work drop each other from member_ids. The entry records a
#     pending relationship instead, and CreateRelationshipsJob attaches every
#     file set for the work in one pass, then queues its ingest.
#   - fail a row whose parent cannot be found, or is not a work, before
#     creating or updating anything, since the file set and its upload would
#     be left behind unattached.
#   - fail a re-imported row whose file set is already in another work, before
#     updating anything, since the relationship pass would add it to a second
#     work rather than move it.
#   - give the file set the row's visibility, which Bulkrax drops because it
#     passes file set params without the uploaded file id the handler matches
#     on. A row without one, or with embargo or lease, which the handler cannot
#     set, inherits the work's visibility, embargo and lease. On re-import
#     only a row with no visibility inherits, and not onto a file set under
#     its own embargo or lease; upstream applies a row's own.
#   - fail a row that lists more than one file, since the row's one identifier
#     can relate only one file set to the work.
module Bulkrax
  module ValkyrieObjectFactoryFileSetDecorator
    private

    def create_file_set(attrs)
      attrs = HashWithIndifferentAccess.new(attrs)
      parent = parent_work
      uploaded_files, = prep_fileset_content(attrs)
      raise StandardError, "#{source_identifier_value} lists #{uploaded_files.size} files; a file set row takes one" if uploaded_files.size > 1

      params = attrs.merge(attributes).symbolize_keys
      params.delete(:visibility) unless row_visibility?
      attach_unrelated(parent, uploaded_files, params)
    end

    def update_file_set(attrs)
      parent = parent_work
      reject_move(to: parent)
      file_set = super
      # A row's own visibility, embargo or lease is applied by upstream's form
      return file_set if attributes[:visibility].present? || own_embargo_or_lease?(file_set)

      inherit_access(from: parent, to: file_set)
    end

    def own_embargo_or_lease?(file_set)
      Hyrax::EmbargoManager.new(resource: file_set).under_embargo? || Hyrax::LeaseManager.new(resource: file_set).under_lease?
    end

    def parent_work
      parent_identifier = attributes[related_parents_parsed_mapping]&.first
      parent = find_record(parent_identifier, importer_run_id).last
      raise StandardError, "#{source_identifier_value} has no parent work #{parent_identifier} to attach to" if parent.nil?
      raise StandardError, "#{source_identifier_value} names #{parent_identifier} as its parent, which is not a work" unless parent.work?

      parent
    end

    def reject_move(to:)
      current = Hyrax.custom_queries.find_parent_work(resource: object)
      return if current.nil? || current.id == to.id

      raise StandardError, "#{source_identifier_value} is already in work #{current.id}; moving a file set to #{to.id} is not supported"
    end

    def row_visibility?
      Hyrax.config.visibility_map.visibilities.include?(attributes[:visibility])
    end

    def attach_unrelated(parent, uploaded_files, params)
      file_set_params = uploaded_files.map { |file| params.merge(uploaded_file_id: file.id.to_s) }
      payload = HykuKnapsack::UnattachedUploadsHandler.new(work: parent).add(files: uploaded_files, file_set_params:).attach.first
      raise StandardError, "#{source_identifier_value} has no file to attach" unless payload

      return payload[:file_set] if params[:visibility].present?

      inherit_access(from: parent, to: payload[:file_set])
    end

    def inherit_access(from:, to:)
      to.visibility = from.visibility
      embargoed = Hyrax::EmbargoManager.new(resource: from).copy_embargo_to(target: to)
      leased = Hyrax::LeaseManager.new(resource: from).copy_lease_to(target: to)
      return to unless embargoed || leased || to.permission_manager.acl.pending_changes?

      to.permission_manager.acl.save
      Hyrax.persister.save(resource: to).tap { |saved| Hyrax.index_adapter.save(resource: saved) }
    end
  end
end

Bulkrax::ValkyrieObjectFactory.prepend(Bulkrax::ValkyrieObjectFactoryFileSetDecorator)
