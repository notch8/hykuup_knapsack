# frozen_string_literal: true
# OVERRIDE Hyrax v5.0.4 to add logging and reporting of derivative errors to Sentry
module ValkyrieCreateDerivativesJobDecorator
  # rubocop:disable Metrics/MethodLength
  def perform(file_set_id, file_id, _filepath = nil)
    begin
      super
    rescue => e
      Rails.logger.error("[DerivativesJob] FileSet: #{file_set_id} — #{e.class}: #{e.message}")
      Rails.logger.debug { e.backtrace.join("\n") }

      if defined?(Sentry)
        Sentry.capture_exception(e, extra: {
                                   job: "ValkyrieCreateDerivativesJob",
                                   file_set_id:,
                                   file_id:
                                 })
      end

      raise
    end
  end
  # rubocop:enable Metrics/MethodLength
end
::ValkyrieCreateDerivativesJob.prepend(ValkyrieCreateDerivativesJobDecorator)