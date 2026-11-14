# frozen_string_literal: true

# OVERRIDE Hyku v7.1.0 - end every demo reset with an admin set the admin group manages.
# Hyku makes one only during the seed import; without one nobody can deposit or import.
module DemoTenantResetServiceDefaultAdminSetDecorator
  private

  # The first step after the Solr wipe and the visitor revocation, and before the
  # seed import, which then reuses this admin set.
  def restore_site!
    ensure_default_admin_set!
    super
  end

  def ensure_default_admin_set!
    ensure_default_groups!
    clear_stale_default_admin_set_ids!
    admin_set = Hyrax.query_service.find_all_of_model(model: Hyrax.config.admin_set_class).first ||
                Hyrax::AdminSetCreateService.find_or_create_default_admin_set
    # The deposit form looks up the default, and would otherwise create a second admin set.
    Hyrax::DefaultAdministrativeSet.update(default_admin_set_id: admin_set.id) unless Hyrax::DefaultAdministrativeSet.exists?
    grant_admin_group_manage!(admin_set)
    # ReindexAdminSetsJob only queues the reindex, and deposit rights are read from Solr.
    Hyrax.index_adapter.save(resource: admin_set)
    log "admin set #{admin_set.id} is in place"
  end

  # Hyrax raises rather than finding or creating one while the saved default id points at a deleted admin set.
  def clear_stale_default_admin_set_ids!
    Hyrax::DefaultAdministrativeSet.find_each do |row|
      Hyrax.query_service.find_by(id: row.default_admin_set_id)
    rescue Valkyrie::Persistence::ObjectNotFoundError
      row.destroy!
      log "cleared stale default admin set id #{row.default_admin_set_id}"
    end
  end

  def grant_admin_group_manage!(admin_set)
    grant = { agent_type: Hyrax::PermissionTemplateAccess::GROUP, agent_id: ::Ability.admin_group_name,
              access: Hyrax::PermissionTemplateAccess::MANAGE }
    template = Hyrax::PermissionTemplate.find_by(source_id: admin_set.id.to_s)
    return if template&.access_grants&.exists?(grant)

    if template
      Hyrax::Collections::PermissionsCreateService.add_access(collection_id: admin_set.id, grants: [grant])
    else
      # Hyrax saves an admin set before its template and workflows, so a failed create leaves it with neither.
      Hyrax::AdminSetCreateService.new(admin_set:, creating_user: nil).create!
    end
    log "granted the #{::Ability.admin_group_name} group Manage on admin set #{admin_set.id}"
  end
end

DemoTenantResetService.prepend(DemoTenantResetServiceDefaultAdminSetDecorator)
