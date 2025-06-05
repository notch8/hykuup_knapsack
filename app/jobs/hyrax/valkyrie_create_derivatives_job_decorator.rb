# frozen_string_literal: true
# OVERRIDE to log and report derivative errors to Sentry
ValkyrieCreateDerivativesJob.class_eval do
  # rubocop:disable Metrics/MethodLength
  def perform(file_set_id, file_id, _filepath = nil)
    file_metadata = Hyrax.custom_queries.find_file_metadata_by(id: file_id)
    return if file_metadata.video? && !Hyrax.config.enable_ffmpeg

    file = Hyrax.storage_adapter.find_by(id: file_metadata.file_identifier)

    begin
      derivative_service = Hyrax::DerivativeService.for(file_metadata)
      derivative_service.create_derivatives(file.disk_path)
      reindex_parent(file_set_id)
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
