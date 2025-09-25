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
        all_work_types = Hyrax.config.registered_curation_concern_types
        excluded_work_types = tenant_excluded_work_types
        
        all_work_types - excluded_work_types
      rescue => e
        Rails.logger.warn "Error in tenant filtering: #{e.message}"
        # Fallback to all registered work types if filtering fails
        Hyrax.config.registered_curation_concern_types
      end
    end

    # Returns work types that should be excluded for the current tenant
    def tenant_excluded_work_types
      case current_tenant_cname
      when 'unca.hykuup.com'
        # UNCA cannot see: MobiusWork
        %w[MobiusWork]
      when /\.digitalmobius\.org$/
        # Mobius cannot see: UncaWork, ScholarlyWork
        %w[UncaWork ScholarlyWork]
      else
        # Generic tenants cannot see: MobiusWork, UncaWork, ScholarlyWork
        %w[MobiusWork UncaWork ScholarlyWork]
      end
    end

    def current_tenant_cname
      return nil unless defined?(Account)
      
      current_tenant = Apartment::Tenant.current
      return nil unless current_tenant
      
      Account.find_by(tenant: current_tenant)&.cname
    end
  end
end

Hyrax::QuickClassificationQuery.prepend(Hyrax::QuickClassificationQueryDecorator)
