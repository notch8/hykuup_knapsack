# frozen_string_literal: true

# Service class for tenant-specific configuration and filtering
class TenantWorkTypeFilter
  class << self
    # Returns work types that should be excluded for the current tenant
    # @return [Array<String>] Array of work type names to exclude
    def excluded_work_types
      case current_tenant_cname
      when 'unca.hykuup.com'
        # UNCA cannot see: MobiusWork, UncaWork (deprecated)
        %w[MobiusWork UncaWork]
      when /\.digitalmobius\.org$/
        # Mobius cannot see: UncaWork, ScholarlyWork
        %w[UncaWork ScholarlyWork]
      else
        # Generic tenants cannot see: MobiusWork, UncaWork, ScholarlyWork
        %w[MobiusWork UncaWork ScholarlyWork]
      end
    end

    # Returns work types that the current tenant is allowed to use
    # @return [Array<String>] Array of work type names that are allowed
    def allowed_work_types
      all_work_types = Hyrax.config.registered_curation_concern_types
      excluded_work_types = self.excluded_work_types

      all_work_types - excluded_work_types
    end

    # Returns the metadata profile path for the current tenant
    # @param default_path [String] The default profile path to use as fallback
    # @return [String] Path to the tenant-specific metadata profile
    def tenant_metadata_profile_path(default_path)
      case current_tenant_cname
      when 'unca.hykuup.com'
        HykuKnapsack::Engine.root.join('config', 'metadata_profiles', 'unca', 'm3_profile.yaml')
      when /\.digitalmobius\.org$/
        HykuKnapsack::Engine.root.join('config', 'metadata_profiles', 'mobius', 'm3_profile.yaml')
      else
        default_path
      end
    end

    # Returns the current tenant's cname
    # @return [String, nil] The tenant's cname or nil if not found
    def current_tenant_cname
      return nil unless defined?(Account)

      current_tenant = Apartment::Tenant.current
      return nil unless current_tenant

      Account.find_by(tenant: current_tenant)&.cname
    end
  end
end
