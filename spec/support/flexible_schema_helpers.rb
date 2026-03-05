# frozen_string_literal: true

# Helpers for seeding Hyrax::FlexibleSchema records in specs.
# In flexible mode, model attributes (including core fields like `depositor`)
# come from the database-backed FlexibleSchema rather than hardcoded includes.
# Specs that instantiate flexible work types must seed the schema first.
module FlexibleSchemaHelpers
  PROFILE_PATHS = {
    'ScholarlyWork' => HykuKnapsack::Engine.root.join('config', 'metadata_profiles', 'unca', 'm3_profile.yaml'),
    'MobiusWork' => HykuKnapsack::Engine.root.join('config', 'metadata_profiles', 'mobius', 'm3_profile.yaml')
  }.freeze

  def seed_flexible_schema_for(work_type)
    path = PROFILE_PATHS.fetch(work_type.to_s)
    profile = YAML.safe_load_file(path)
    Hyrax::FlexibleSchema.delete_all
    Hyrax::FlexibleSchema.create!(profile: profile)
  end
end

RSpec.configure do |config|
  config.include FlexibleSchemaHelpers
end
