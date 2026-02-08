# frozen_string_literal: true

# OpenTelemetry tracing configuration
# Traces are exported to the local Alloy collector via OTLP,
# which then forwards them to the central Tempo instance.
#
# Required environment variables:
#   OTEL_EXPORTER_OTLP_ENDPOINT - e.g. http://alloy.monitoring.svc.cluster.local:4318
#   OTEL_SERVICE_NAME            - e.g. hykuup-knapsack-production (set automatically below if not present)
#
# To disable tracing, omit the OTEL_EXPORTER_OTLP_ENDPOINT env var.
if ENV['OTEL_EXPORTER_OTLP_ENDPOINT'].present?
  require 'opentelemetry/sdk'
  require 'opentelemetry/exporter/otlp'
  require 'opentelemetry/instrumentation/all'

  # Determine version safely — this initializer may run before version.rb is loaded
  app_version = defined?(HykuKnapsack::VERSION) ? HykuKnapsack::VERSION : 'unknown'

  OpenTelemetry::SDK.configure do |c|
    # Dynamic service name: OTEL_SERVICE_NAME > SENTRY_ENVIRONMENT > derived from HYKU_ADMIN_HOST
    c.service_name = ENV.fetch('OTEL_SERVICE_NAME') {
      ENV.fetch('SENTRY_ENVIRONMENT') {
        "hykuup-#{ENV.fetch('HYKU_ADMIN_HOST', 'unknown').split('.').first}"
      }
    }

    # Resource attributes for better trace identification
    c.resource = OpenTelemetry::SDK::Resources::Resource.create(
      'deployment.environment' => ENV.fetch('RAILS_ENV', 'production'),
      'service.namespace' => 'hykuup-knapsack',
      'service.version' => app_version
    )

    # Auto-instrument Rails, ActiveRecord, Faraday, Net::HTTP, Rack, Sidekiq, etc.
    c.use_all
  end

  Rails.logger.info "[OpenTelemetry] Tracing enabled → #{ENV['OTEL_EXPORTER_OTLP_ENDPOINT']}"
else
  Rails.logger.info "[OpenTelemetry] Tracing disabled (OTEL_EXPORTER_OTLP_ENDPOINT not set)"
end
