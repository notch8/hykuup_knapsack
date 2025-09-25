# frozen_string_literal: true

# Use this to override any Hyrax configuration from the Knapsack

# rubocop:disable Metrics/BlockLength
Rails.application.config.after_initialize do
  Hyrax.config do |config|
    config.flexible = ActiveModel::Type::Boolean.new.cast(ENV.fetch('HYRAX_FLEXIBLE', false))

    # Set default profile path (fallback)
    config.default_m3_profile_path = HykuKnapsack::Engine.root.join('config', 'metadata_profiles', 'default', 'm3_profile.yaml')

    config.register_curation_concern :mobius_work
    config.register_curation_concern :unca_work
    config.register_curation_concern :scholarly_work
  end

  # Override the create_default_schema method to load tenant-specific profiles
  Hyrax::FlexibleSchema.class_eval do
    def self.create_default_schema
      m3_profile_path = tenant_specific_profile_path

      # Clear existing profiles to ensure we load the correct tenant-specific one
      Hyrax::FlexibleSchema.destroy_all

      Hyrax::FlexibleSchema.create do |f|
        f.profile = YAML.safe_load_file(m3_profile_path)
      end
    end

    def self.tenant_specific_profile_path
      return default_profile_path unless defined?(Account)

      current_tenant = Apartment::Tenant.current
      return default_profile_path unless current_tenant

      account = Account.find_by(tenant: current_tenant)
      return default_profile_path unless account

      TenantWorkTypeFilter.tenant_metadata_profile_path(default_profile_path)
    end

    def self.default_profile_path
      Hyrax.config.default_m3_profile_path || Rails.root.join('config', 'metadata_profiles', 'm3_profile.yaml')
    end
  end
end
# rubocop:enable Metrics/BlockLength
