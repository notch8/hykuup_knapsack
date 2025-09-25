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
      tenant_allowed_types = TenantWorkTypeFilter.allowed_work_types
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
      tenant_allowed_types = TenantWorkTypeFilter.allowed_work_types
      allowed_work_types = profile_work_types & tenant_allowed_types & Hyrax.config.registered_curation_concern_types

      available_works & allowed_work_types
    end
  end
end

Admin::WorkTypesController.prepend(Admin::WorkTypesControllerDecorator)
