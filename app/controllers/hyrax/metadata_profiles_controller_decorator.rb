# frozen_string_literal: true

# OVERRIDE Hyku v6.2.0: Add tenant-specific validation for metadata profile uploads
module Hyrax
  module MetadataProfilesControllerDecorator
    extend ActiveSupport::Concern

    private

    # OVERRIDE: Add tenant-specific validation before creating the profile
    # rubocop:disable Metrics/MethodLength
    def import
      return redirect_to_index_with_alert unless uploaded_file_present?

      begin
        profile_data = YAML.safe_load_file(params[:file].path)

        # Validate that the profile doesn't contain work types the tenant doesn't "own"
        validate_tenant_work_types!(profile_data)

        @flexible_schema = Hyrax::FlexibleSchema.create(profile: profile_data)

        if @flexible_schema.persisted?
          redirect_to metadata_profiles_path, notice: 'Flexible Metadata Profile was successfully created.'
        else
          error_message = @flexible_schema.errors.messages.values.flatten.join(', ')
          redirect_to metadata_profiles_path, flash: { error: error_message }
        end
      rescue => e
        redirect_to metadata_profiles_path, flash: { error: e.message }
        nil
      end
    end
    # rubocop:enable Metrics/MethodLength

    def uploaded_file_present?
      params[:file].present?
    end

    def redirect_to_index_with_alert
      redirect_to metadata_profiles_path, alert: 'Please select a file to upload'
    end

    # Validates that the profile doesn't contain work types the current tenant doesn't "own"
    def validate_tenant_work_types!(profile_data)
      return unless profile_data&.dig('classes')

      profile_work_types = extract_profile_work_types(profile_data)
      excluded_work_types = TenantWorkTypeFilter.excluded_work_types

      # Check if the profile contains any work types this tenant shouldn't see
      forbidden_work_types = profile_work_types & excluded_work_types

      return unless forbidden_work_types.any?
      tenant_name = TenantWorkTypeFilter.current_tenant_cname || 'this tenant'
      allowed_work_types = TenantWorkTypeFilter.allowed_work_types

      raise StandardError,
            "This profile contains work types (#{forbidden_work_types.join(', ')}) that are not allowed for #{tenant_name}. " \
            "Please use a profile that only contains work types appropriate for your tenant. " \
            "Allowed work types for #{tenant_name}: #{allowed_work_types.join(', ')}."
    end

    def extract_profile_work_types(profile_data)
      profile_classes = profile_data.dig('classes')&.keys || []
      profile_classes.map { |klass| klass.gsub(/Resource$/, '') }
    end
  end
end

Hyrax::MetadataProfilesController.prepend(Hyrax::MetadataProfilesControllerDecorator)
