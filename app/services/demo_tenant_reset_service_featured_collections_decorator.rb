# frozen_string_literal: true

# OVERRIDE Hyku v7.1.0 - snapshot and restore featured collections, as Hyku
# already does for featured works.
#
# The reset wipes FeaturedCollection rows and the reimport gives collections new
# ids, so the snapshot records each one by import identifier and display order.
module DemoTenantResetServiceFeaturedCollectionsDecorator
  def snapshot!(**)
    snap = super
    within_tenant { snap['featured_collections'] = featured_collection_entries }
    account.update!(demo_tenant_snapshot: snap)
    log "captured #{snap['featured_collections'].size} featured collections"
    snap
  end

  private

  def restore_featured_works!
    super
    restore_featured_collections!
  end

  def featured_collection_entries
    FeaturedCollection.all.filter_map do |featured|
      collection = find_resource(featured.collection_id)
      identifier = collection && work_identifier(collection)
      { 'identifier' => identifier.to_s, 'order' => featured.order } if identifier
    end
  end

  def restore_featured_collections!
    entries = Array(account.demo_tenant_snapshot['featured_collections'])
    return if entries.empty?

    FeaturedCollection.destroy_all
    index = Hyrax.query_service.find_all_of_model(model: Hyrax.config.collection_class)
                 .index_by { |collection| work_identifier(collection).to_s }
    entries.each do |entry|
      collection = index[entry['identifier']]
      next log("featured collection #{entry['identifier']} not found after import", level: :warn) unless collection

      FeaturedCollection.create!(collection_id: collection.id.to_s, order: entry['order'])
    end
    log "restored #{FeaturedCollection.count} featured collections"
  end
end

DemoTenantResetService.prepend(DemoTenantResetServiceFeaturedCollectionsDecorator)
