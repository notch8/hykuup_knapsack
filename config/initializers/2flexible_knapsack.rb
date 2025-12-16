# frozen_string_literal: true

# Override HYRAX_FLEXIBLE_CLASSES with knapsack-specific work types
# This replaces the submodule's 1flexible.rb classes with our custom classes
# matching the m3_profile.yaml

flexible = ActiveModel::Type::Boolean.new.cast(ENV.fetch('HYRAX_FLEXIBLE', 'true'))
if flexible
  # Set knapsack-specific classes (matching m3_profile.yaml)
  # These REPLACE the submodule's classes entirely
  knapsack_classes = %w[
    AdminSetResource
    CollectionResource
    Hyrax::FileSet
  ]

  ENV['HYRAX_FLEXIBLE_CLASSES'] = knapsack_classes.join(',')
end
