# frozen_string_literal: true

# Use this to override any Hyrax configuration from the Knapsack

Rails.application.config.after_initialize do
  Hyrax.config do |config|
    config.default_m3_profile_path = HykuKnapsack::Engine.root.join('config', 'metadata_profiles', 'm3_profile.yaml')

    config.register_curation_concern :mobius_work
    config.register_curation_concern :unca_work
  end
end
