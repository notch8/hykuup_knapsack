# frozen_string_literal: true

# Pyroscope continuous profiling configuration
# CPU flame graphs are sent to the local Alloy collector,
# which forwards them to the central Pyroscope instance.
#
# Required environment variables:
#   PYROSCOPE_SERVER_ADDRESS - e.g. http://alloy.monitoring.svc.cluster.local:4040
#
# Optional:
#   PYROSCOPE_APPLICATION_NAME - defaults to SENTRY_ENVIRONMENT or "hykuup-knapsack-unknown"
#
# To disable profiling, omit the PYROSCOPE_SERVER_ADDRESS env var.
if ENV['PYROSCOPE_SERVER_ADDRESS'].present?
  require 'pyroscope'

  Pyroscope.configure do |config|
    # Dynamic app name: PYROSCOPE_APPLICATION_NAME > SENTRY_ENVIRONMENT > fallback
    config.application_name = ENV.fetch('PYROSCOPE_APPLICATION_NAME', "my-app-#{Rails.env}")

    config.server_address = ENV['PYROSCOPE_SERVER_ADDRESS']

    # Tag profiles with environment metadata for filtering in Grafana
    config.tags = {
      "hostname" => ENV.fetch("HOSTNAME", "unknown"),
      "rails_env" => ENV.fetch("RAILS_ENV", "production"),
      "service_namespace" => "hykuup-knapsack"
    }

    # Rails auto-instrumentation: tags profiles with controller/action
    config.autoinstrument_rails = true
  end

  Rails.logger.info "[Pyroscope] Profiling enabled → #{ENV['PYROSCOPE_SERVER_ADDRESS']}"
else
  Rails.logger.info "[Pyroscope] Profiling disabled (PYROSCOPE_SERVER_ADDRESS not set)"
end
