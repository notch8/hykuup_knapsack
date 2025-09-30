# frozen_string_literal: true

# Use this to override any Hyrax configuration from the Knapsack

# rubocop:disable Metrics/BlockLength
Rails.application.config.after_initialize do
  Hyrax.config do |config|
    config.flexible = ActiveModel::Type::Boolean.new.cast(ENV.fetch('HYRAX_FLEXIBLE', false))

    # Set default profile path
    config.default_m3_profile_path = HykuKnapsack::Engine.root.join('config', 'metadata_profiles', 'default', 'm3_profile.yaml')

    config.register_curation_concern :mobius_work
    config.register_curation_concern :unca_work
    config.register_curation_concern :scholarly_work
  end

  # Override Hyrax v5.0.5: the create_default_schema method to load tenant-specific profiles
  Hyrax::FlexibleSchema.class_eval do
    def self.create_default_schema
      m3_profile_path = tenant_specific_profile_path

      # Only create if no schema exists
      return Hyrax::FlexibleSchema.first if Hyrax::FlexibleSchema.exists?

      Hyrax::FlexibleSchema.create do |f|
        f.profile = YAML.safe_load_file(m3_profile_path)
      end
    end

    def self.force_create_default_schema
      # Force creates a new flexible schema for the current tenant.
      # This method is intended for use by rake tasks that need to ensure
      # a new schema is created, even if one already exists.
      #
      # @return [Hyrax::FlexibleSchema] The newly created schema
      # @see create_default_schema for the safe version used during app startup
      m3_profile_path = tenant_specific_profile_path

      # Always create a new schema (for rake tasks)
      Hyrax::FlexibleSchema.create do |f|
        f.profile = YAML.safe_load_file(m3_profile_path)
      end
    end

    def self.tenant_specific_profile_path
      return Hyrax.config.default_m3_profile_path unless defined?(Account) && Apartment::Tenant.current

      account = Account.find_by(tenant: Apartment::Tenant.current)
      return Hyrax.config.default_m3_profile_path unless account

      TenantWorkTypeFilter.tenant_metadata_profile_path(Hyrax.config.default_m3_profile_path)
    end
  end
end
# rubocop:enable Metrics/BlockLength
