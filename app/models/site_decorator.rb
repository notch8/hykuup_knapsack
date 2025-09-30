# frozen_string_literal: true

# OVERRIDE Hyku v6.2.0: Use tenant-specific work types based on consortium membership
module SiteDecorator
  extend ActiveSupport::Concern

  class_methods do
    # OVERRIDE: Use tenant-specific available works based on consortium membership
    # @return [Site] Site instance with tenant-specific work types
    def instance
      return NilSite.instance if Account.global_tenant?
      first_or_create do |site|
        site.available_works = tenant_available_works
      end
    end

    private

    # Get available work types for the current tenant based on consortium membership
    # @return [Array<String>] Array of work type names available to this tenant
    def tenant_available_works
      return Hyrax.config.registered_curation_concern_types unless defined?(TenantWorkTypeFilter)

      TenantWorkTypeFilter.allowed_work_types
    rescue => e
      Rails.logger.warn "Failed to get tenant-specific work types: #{e.message}"
      Hyrax.config.registered_curation_concern_types
    end
  end
end

Site.prepend(SiteDecorator)
