# frozen_string_literal: true

require 'sentry-ruby'
require 'sentry-sidekiq'

Sentry.init do |config|
  config.dsn = ENV['SENTRY_DSN']
  config.environment = ENV['SENTRY_ENVIRONMENT']
  config.breadcrumbs_logger = [:active_support_logger, :http_logger]
  # TODO: remove hykuup-knapsack-argo when spinning down environment
  config.enabled_environments = %w[hykuup-knapsack-friends hykuup-knapsack-staging hykuup-knapsack-argo hykuup-knapsack-production]
  config.debug = true
end
