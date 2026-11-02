# frozen_string_literal: true

# Saves a HykuUP showcase tenant's current look as the one its resets restore.
class ShowcaseSnapshotJob < ApplicationJob
  retry_on StandardError, wait: :polynomially_longer, attempts: 3 do |job, exception|
    Rails.logger.error("[DemoTenantReset] tenant=#{job.tenant} save current look failed: #{exception.message}")
    Sentry.capture_exception(exception) if defined?(Sentry)
  end

  def perform
    DemoTenantResetService.new(account: current_account).snapshot!(force: true)
  end
end
