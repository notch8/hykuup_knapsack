# frozen_string_literal: true

# OVERRIDE Hyku v6.2.0: Add tenant-specific validation for metadata profile uploads
module Hyrax
  module Admin
    module MetadataProfilesControllerDecorator
      extend ActiveSupport::Concern

      private

      # OVERRIDE: Add tenant-specific validation before creating the profile
      # @return [void]
      # @raise [StandardError] if profile contains restricted work types for the current tenant
      def import
        return redirect_to_index_with_alert unless uploaded_file_present?

        begin
          profile_data = YAML.safe_load_file(params[:file].path)

          # Validate tenant work types (custom validation)
          validate_tenant_work_types!(profile_data)

          # Run full profile validation (includes existing records check)
          validator = Hyrax::FlexibleSchemaValidatorService.new(profile: profile_data)
          validator.validate!

          raise StandardError, validator.errors.join('; ') if validator.errors.any?

          create_flexible_schema(profile_data)
        rescue => e
          redirect_to metadata_profiles_path, flash: { error: e.message }
          nil
        end
      end

      # Check if a file was uploaded in the request parameters
      # @return [Boolean] true if a file was uploaded, false otherwise
      def uploaded_file_present?
        params[:file].present?
      end

      # Redirect to the metadata profiles index with an alert message
      # @return [void]
      def redirect_to_index_with_alert
        redirect_to metadata_profiles_path, alert: 'Please select a file to upload'
      end

      # Create the flexible schema and handle the response
      # @param profile_data [Hash] The parsed YAML profile data
      # @return [void]
      def create_flexible_schema(profile_data)
        @flexible_schema = Hyrax::FlexibleSchema.create(profile: profile_data)

        if @flexible_schema.persisted?
          redirect_to metadata_profiles_path, notice: 'Flexible Metadata Profile was successfully created.'
        else
          error_message = @flexible_schema.errors.messages.values.flatten.join(', ')
          redirect_to metadata_profiles_path, flash: { error: error_message }
        end
      end

      # Validates that the profile doesn't contain work types restricted for the current tenant
      # @param profile_data [Hash] The parsed YAML profile data
      # @return [void]
      # @raise [StandardError] if profile contains work types not allowed for the current tenant
      def validate_tenant_work_types!(profile_data)
        return unless profile_data&.dig('classes')

        profile_work_types = extract_profile_work_types(profile_data)
        excluded_work_types = TenantWorkTypeFilter.excluded_work_types

        forbidden_work_types = profile_work_types & excluded_work_types

        return unless forbidden_work_types.any?

        account = current_tenant_account
        tenant_name = account&.cname || 'this tenant'
        allowed_work_types = TenantWorkTypeFilter.allowed_work_types

        raise StandardError,
              "This profile contains work types (#{forbidden_work_types.join(', ')}) that are not allowed for #{tenant_name}. " \
              "Please use a profile that only contains work types appropriate for your tenant. " \
              "Allowed work types for #{tenant_name}: #{allowed_work_types.join(', ')}."
      end

      # Extract work type names from the profile data
      # @param profile_data [Hash] The parsed YAML profile data
      # @return [Array<String>] Array of work type names found in the profile
      def extract_profile_work_types(profile_data)
        profile_classes = profile_data.dig('classes')&.keys || []
        profile_classes.map { |klass| klass.gsub(/Resource$/, '') }
      end

      # Fetches the Account object for the current tenant.
      # @return [Account, nil]
      def current_tenant_account
        return nil unless defined?(Account) && Apartment::Tenant.current

        Account.find_by(tenant: Apartment::Tenant.current)
      end
    end
  end
end

Hyrax::Admin::MetadataProfilesController.prepend(Hyrax::Admin::MetadataProfilesControllerDecorator)
