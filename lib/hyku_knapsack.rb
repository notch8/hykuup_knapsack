# frozen_string_literal: true

# Force HYRAX_FLEXIBLE to true for this app (it always runs with flexible metadata)
# This must be set before the engine is required, and before any Hyrax code loads
# to prevent the Hyrax gem's spec_helper or other code from setting it to false
# This is needed for the CI pipeline to pass and honor HYRAX_FLEXIBLE=true
ENV['HYRAX_FLEXIBLE'] = 'true'

require "hyku_knapsack/version"
require "hyku_knapsack/engine"

# Explicitly disable include_metadata for flexible mode to prevent loading core_metadata schema
# This must be set very early, before models are loaded (which can happen during engine initialization)
ENV['HYRAX_DISABLE_INCLUDE_METADATA'] = 'true' if ENV.fetch('HYRAX_FLEXIBLE', 'true') != 'false'

module HykuKnapsack
  # Your code goes here...
end
