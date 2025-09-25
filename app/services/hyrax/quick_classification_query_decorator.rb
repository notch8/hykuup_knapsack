# frozen_string_literal: true

# OVERRIDE Hyku v6.2.0: Apply tenant-specific work type filtering to work creation
module Hyrax
  module QuickClassificationQueryDecorator
    extend ActiveSupport::Concern

    # OVERRIDE: Apply tenant-specific filtering to work types available for creation
    def authorized_models
      original_models = super
      
      filtered_models = tenant_filtered_work_types
      
      original_models.select { |model| filtered_models.include?(model.name) }
    end

    # OVERRIDE: Check if all tenant-allowed work types are available
    def all?
      models == tenant_filtered_work_types
    end

    private

    # Returns work types that the current tenant is allowed to create
    def tenant_filtered_work_types
      begin
        TenantWorkTypeFilter.allowed_work_types
      rescue => e
        Rails.logger.warn "Error in tenant filtering: #{e.message}"
        # Fallback to all registered work types if filtering fails
        Hyrax.config.registered_curation_concern_types
      end
    end
  end
end

Hyrax::QuickClassificationQuery.prepend(Hyrax::QuickClassificationQueryDecorator)
