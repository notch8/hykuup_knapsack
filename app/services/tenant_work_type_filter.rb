# frozen_string_literal: true

# Service class for tenant-specific configuration and filtering
class TenantWorkTypeFilter
  class << self
    # Returns work types that should be excluded for the current tenant
    # @return [Array<String>] Array of work type names to exclude
    def excluded_work_types
      consortium = current_tenant_consortium
      return default_excluded_work_types unless consortium

      consortium_config = find_consortium_config(consortium)
      return default_excluded_work_types unless consortium_config

      consortium_config['excluded_work_types'] || default_excluded_work_types
    end

    # Returns work types that the current tenant is allowed to use
    # @return [Array<String>] Array of work type names that are allowed
    def allowed_work_types
      all_work_types = Hyrax.config.registered_curation_concern_types
      excluded_work_types = self.excluded_work_types

      all_work_types - excluded_work_types
    end

    # Returns work types the current tenant may offer, narrowed by its metadata profile
    #
    # [] means no profile constraint, not "nothing allowed": callers must fall back to
    # their unfiltered list or a non-flexible tenant loses every work type.
    #
    # @return [Array<String>] Array of work type names, or [] when no profile applies
    def profile_allowed_work_types
      return [] unless Hyrax.config.flexible?

      profile = Hyrax::FlexibleSchema.current_version
      return [] unless profile

      profile_classes = profile['classes']&.keys || []
      profile_work_types = profile_classes.map { |klass| klass.gsub(/Resource$/, '') }

      profile_work_types & allowed_work_types & Hyrax.config.registered_curation_concern_types
    end

    # Returns work types this tenant may actually offer a depositor
    #
    # Mirrors what Hyku's QuickClassificationQueryDecorator computes for the picker.
    #
    # @return [Array<String>] Array of work type names
    def offerable_work_types
      available_works = Site.instance.available_works || []
      declared = profile_allowed_work_types
      return available_works if declared.empty?

      available_works & declared
    end

    # Returns the metadata profile path for the current tenant
    # @param default_path [String] The default profile path to use as fallback
    # @return [String] Path to the tenant-specific metadata profile
    def tenant_metadata_profile_path(default_path)
      consortium = current_tenant_consortium
      return default_path unless consortium

      consortium_profile_path = HykuKnapsack::Engine.root.join('config', 'metadata_profiles', consortium, 'm3_profile.yaml')

      # Check if consortium-specific profile exists, otherwise fall back to default
      File.exist?(consortium_profile_path) ? consortium_profile_path : default_path
    end

    # Returns the current tenant's consortium membership
    # @return [String, nil] The consortium name or nil if not part of any consortium
    def current_tenant_consortium
      return nil unless defined?(Account)

      current_tenant = Apartment::Tenant.current
      return nil unless current_tenant

      Account.find_by(tenant: current_tenant)&.part_of_consortia
    end

    private

    # Returns the default excluded work types for tenants without consortium membership
    # @return [Array<String>] Default excluded work types
    def default_excluded_work_types
      %w[MobiusWork ScholarlyWork]
    end

    # Finds the consortium configuration from the YAML file
    # @param consortium_identifier [String] The consortium identifier to find
    # @return [Hash, nil] The consortium configuration or nil if not found
    def find_consortium_config(consortium_identifier)
      consortia_config.find { |consortium| consortium['identifier'] == consortium_identifier }
    end

    # Loads and caches the consortia configuration from YAML
    # @return [Array<Hash>] Array of consortium configurations
    def consortia_config
      @consortia_config ||= YAML.load_file(HykuKnapsack::Engine.root.join('config', 'consortia.yml'))
    rescue Errno::ENOENT
      Rails.logger.warn "Consortia config file not found at config/consortia.yml. Using defaults."
      []
    end
  end
end
