# frozen_string_literal: true

# Force HYRAX_FLEXIBLE to true for this app when using flexible metadata (Hyku 7).
# Set before the engine is required so initializers and Hyrax read the correct value.
ENV['HYRAX_FLEXIBLE'] = 'true'

require "hyku_knapsack/version"
require "hyku_knapsack/engine"

ENV['HYRAX_DISABLE_INCLUDE_METADATA'] = 'true' if ENV.fetch('HYRAX_FLEXIBLE', 'true') != 'false'

module HykuKnapsack
  # Your code goes here...
end
