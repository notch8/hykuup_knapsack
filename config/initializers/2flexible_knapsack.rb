# frozen_string_literal: true

# Append knapsack-specific work types to the base Hyku flexible classes.
# Because engine initializer load order may run this before the host app's
# 1flexible.rb, we explicitly load it first if the env var isn't set yet.

flexible = ActiveModel::Type::Boolean.new.cast(ENV.fetch('HYRAX_FLEXIBLE', 'true'))
if flexible
  if ENV['HYRAX_FLEXIBLE_CLASSES'].to_s.empty?
    base = Rails.root.join('config', 'initializers', '1flexible.rb')
    load(base) if File.exist?(base)
  end

  existing = ENV.fetch('HYRAX_FLEXIBLE_CLASSES', '').split(',')
  knapsack_additions = %w[
    ScholarlyWork
    MobiusWork
  ]

  ENV['HYRAX_FLEXIBLE_CLASSES'] = (existing + knapsack_additions).uniq.join(',')
end
