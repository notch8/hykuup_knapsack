# frozen_string_literal: true

# Ensure Knapsack version gets loaded after Hyku's bulkrax.rb
Rails.application.config.after_initialize do
  Bulkrax.setup do |config|
    config.fill_in_blank_source_identifiers = ->(parser, index) { "#{Site.account.name}-#{parser.importerexporter.id}-#{index}" }
  end
end
