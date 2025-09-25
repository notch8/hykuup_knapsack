# frozen_string_literal: true

# OVERRIDE Hyku v6.2.0: Hide work types completely based on tenant instead of graying them out
module Admin
  module WorkTypesControllerDecorator
    extend ActiveSupport::Concern

    private

    # OVERRIDE: Filter work types based on tenant ownership
    def setup_profile_work_types
      return unless Hyrax.config.flexible?

      profile = Hyrax::FlexibleSchema.current_version
      return unless profile

      profile_classes = profile['classes']&.keys || []
      profile_work_types = profile_classes.map { |klass| klass.gsub(/Resource$/, '') }
      
      # Apply tenant-specific filtering to hide work types tenants don't "own"
      tenant_allowed_types = tenant_allowed_work_types
      @profile_work_types = profile_work_types & tenant_allowed_types & Hyrax.config.registered_curation_concern_types
    end

    # OVERRIDE: Filter by profile with tenant awareness
    def filter_by_profile(available_works)
      return available_works unless Hyrax.config.flexible?

      profile = Hyrax::FlexibleSchema.current_version
      return available_works unless profile

      profile_classes = profile['classes']&.keys || []
      profile_work_types = profile_classes.map { |klass| klass.gsub(/Resource$/, '') }
      
      # Apply tenant-specific filtering
      tenant_allowed_types = tenant_allowed_work_types
      allowed_work_types = profile_work_types & tenant_allowed_types & Hyrax.config.registered_curation_concern_types

      available_works & allowed_work_types
    end

    # Returns only work types that the current tenant is allowed to see
    def tenant_allowed_work_types
      case current_tenant_cname
      when 'unca.hykuup.com'
        # UNCA can see: GenericWork, Image, OER, ETD, ScholarlyWork, UncaWork
        # UNCA cannot see: MobiusWork
        %w[GenericWork Image Oer Etd ScholarlyWork UncaWork]
      when /\.digitalmobius\.org$/
        # Mobius can see: GenericWork, Image, OER, ETD, MobiusWork
        # Mobius cannot see: UncaWork, ScholarlyWork
        %w[GenericWork Image Oer Etd MobiusWork]
      else
        # Generic tenants can see: GenericWork, Image, OER, ETD
        # Generic tenants cannot see: MobiusWork, UncaWork, ScholarlyWork
        %w[GenericWork Image Oer Etd]
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

Admin::WorkTypesController.prepend(Admin::WorkTypesControllerDecorator)
