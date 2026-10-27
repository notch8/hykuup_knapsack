# frozen_string_literal: true

# OVERRIDE Hyku v7.1.0 - keep collection banners, logos and thumbnails across a
# demo reset.
#
# A reset deletes the collections, so their branding rows point at dead ids and
# the reimported collections have none. The snapshot copies each image into a
# folder of its own and records the import identifier it belongs to, and the
# reset reattaches them.
module DemoTenantResetServiceCollectionBrandingDecorator
  # Copies land in a fresh folder first, so a failed recapture keeps the last good one.
  def snapshot!(**)
    capture_dir = branding_snapshot_root.join(SecureRandom.uuid)
    begin
      branding = within_tenant { capture_collection_branding(capture_dir) }
      snap = super
      snap['collection_branding'] = branding
      account.update!(demo_tenant_snapshot: snap)
    rescue StandardError
      FileUtils.rm_rf(capture_dir)
      raise
    end
    prune_branding_snapshots!(keep: capture_dir)
    log "captured branding for #{branding.map { |e| e['identifier'] }.uniq.size} collections"
    snap
  end

  private

  def restore_featured_works!
    super
    restore_collection_branding!
  end

  def branding_snapshot_root
    Pathname(Hyrax.config.branding_path).join('demo-snapshots', account.tenant.to_s)
  end

  def prune_branding_snapshots!(keep:)
    return unless branding_snapshot_root.exist?

    branding_snapshot_root.children.each { |dir| FileUtils.rm_rf(dir) unless dir == keep }
  end

  # Folders are named by branding row id; import identifiers are not safe path segments.
  def capture_collection_branding(dir)
    CollectionBrandingInfo.all.filter_map do |info|
      collection = find_resource(info.collection_id)
      identifier = collection && work_identifier(collection)
      next unless identifier && File.exist?(info.local_path)

      copy = dir.join(info.id.to_s, File.basename(info.local_path))
      FileUtils.mkdir_p(copy.dirname)
      FileUtils.cp(info.local_path, copy)
      { 'identifier' => identifier.to_s, 'role' => info.role, 'alt_text' => info.alt_text,
        'target_url' => info.target_url, 'file' => copy.to_s }
    end
  end

  def restore_collection_branding!
    entries = Array(account.demo_tenant_snapshot['collection_branding'])
    collections = Hyrax.query_service.find_all_of_model(model: Hyrax.config.collection_class).to_a
    remove_orphaned_branding!(collections)
    return if entries.empty?

    index = collections.index_by { |collection| work_identifier(collection).to_s }
    entries.group_by { |entry| entry['identifier'] }.each do |identifier, branding|
      collection = index[identifier]
      next log("branded collection #{identifier} not found after import", level: :warn) unless collection

      branding.each { |entry| attach_branding(collection, entry) }
      Hyrax.index_adapter.save(resource: collection)
    end
    log "restored branding for #{CollectionBrandingInfo.distinct.count(:collection_id)} collections"
  end

  # CollectionBrandingInfo#delete removes the image only, so the row goes separately.
  def remove_orphaned_branding!(collections)
    orphans = CollectionBrandingInfo.where.not(collection_id: collections.map { |c| c.id.to_s })
    orphans.each(&:delete)
    orphans.delete_all
  end

  # CollectionBrandingInfo#save deletes the file it is given, so it gets a copy.
  def attach_branding(collection, entry)
    return log("branding image #{entry['file']} is missing", level: :warn) unless File.exist?(entry['file'])

    temp = Rails.root.join('tmp', "demo-branding-#{SecureRandom.hex(6)}-#{File.basename(entry['file'])}")
    FileUtils.cp(entry['file'], temp)
    CollectionBrandingInfo.new(collection_id: collection.id.to_s, filename: File.basename(entry['file']),
                               role: entry['role'], alt_txt: entry['alt_text'],
                               target_url: entry['target_url']).save(temp.to_s)
  end
end

DemoTenantResetService.prepend(DemoTenantResetServiceCollectionBrandingDecorator)
