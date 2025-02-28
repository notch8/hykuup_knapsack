# frozen_string_literal: true

# OVERRIDE hyrax to fix job... errors seem to stop the job without raising any error
# - submit a job for each migration
# - add logging messages & rework error handling
# - add permission_template option
class MigrateResourcesJob < ApplicationJob
  # @param models [Array>>String] Array of ActiveFedora model names to migrate to valkyrie objects
  # @param ids [Array>>String or String] Array or string of ids to migrate to valkyrie objects
  # @param permission_template [Boolean] If true, migrate source_ids from all permission templates
  # defaults to AdminSet & Collection models if empty (when using rake task "migrate_collections")
  def perform(ids: [], models: ['AdminSet', 'Collection'], permission_template: false)
    if ids.is_a?(String) || ids.count == 1 # migrate a single id
      migrate(Array.wrap(ids).first)
    elsif ids.count > 1 # migrate an array of multiple ids
      submit_ids_migrations(ids)
    elsif permission_template == true # migrate all admin sets & collections by permission template
      submit_permission_template_migrations
    else # migrate all ids based on model name(s)
      submit_model_migrations(models)
    end
  end

  def submit_ids_migrations(ids)
    ids.each do |id|
      MigrateResourcesJob.perform_later(ids: [id.to_s])
    end
  end

  def submit_permission_template_migrations
    Hyrax::PermissionTemplate.pluck(:source_id).each do |id|
      MigrateResourcesJob.perform_later(ids: [id.to_s])
    end
  end

  def submit_model_migrations(models)
    models.each do |model|
      model.constantize.find_each do |item|
        # find_each shouldn't find anything Valkyrie but we do to_s to be safe
        MigrateResourcesJob.perform_later(ids: [item.id.to_s])
      end
    rescue => e
      Rails.logger.error "🚫 Error processing model #{model}: #{e.message}"
    end
  end

  def migrate(id)
    resource = Hyrax.query_service.find_by(id:)
    return unless resource.wings? # this resource has already been converted
    Rails.logger.info "🍀 Migrating resource #{id} in tenant #{Site.account.name}"
    result = MigrateResourceService.new(resource:).call
    if result.success?
      Rails.logger.info "✅ Migrated resource #{id} successfully"
    else
      Rails.logger.error "🚫 Resource #{id} failed to migrate - #{result}"
      raise result
    end
  rescue Ldp::Gone, Ldp::NotFound, Valkyrie::Persistence::ObjectNotFoundError
    Rails.logger.error "🚫 Resource #{id} not found"
  end
end
