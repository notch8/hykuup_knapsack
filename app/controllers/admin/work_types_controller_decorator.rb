# frozen_string_literal: true

# OVERRIDE Hyku v6.2.0: Hide work types completely based on tenant instead of graying them out
module Admin
  module WorkTypesControllerDecorator
    extend ActiveSupport::Concern

    private

    # OVERRIDE: Filter work types based on tenant-specific visibility rules
    # @return [void]
    def setup_profile_work_types
      @profile_work_types = allowed_work_types_for_profile
    end

    # OVERRIDE: Filter by profile with tenant awareness
    # @param available_works [Array<String>] Array of available work type names
    # @return [Array<String>] Filtered array of work type names
    def filter_by_profile(available_works)
      allowed_types = allowed_work_types_for_profile
      return available_works if allowed_types.empty?

      available_works & allowed_types
    end

    # Extract common logic for determining allowed work types based on profile and tenant
    # @return [Array<String>] Array of work type names that are allowed for the current tenant and profile
    def allowed_work_types_for_profile
      return [] unless Hyrax.config.flexible?

      profile = Hyrax::FlexibleSchema.current_version
      return [] unless profile

      profile_classes = profile['classes']&.keys || []
      profile_work_types = profile_classes.map { |klass| klass.gsub(/Resource$/, '') }

      tenant_allowed_types = TenantWorkTypeFilter.allowed_work_types
      profile_work_types & tenant_allowed_types & Hyrax.config.registered_curation_concern_types
    end
  end
end

Admin::WorkTypesController.prepend(Admin::WorkTypesControllerDecorator)
