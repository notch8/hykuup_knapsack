# frozen_string_literal: true

# OVERRIDE Hyrax v5.3.0 to enforce the tenant's upload limit on the server.
#
# Hyrax advertises Account#file_size_limit to the browser through
# Hyrax.config.uploader[:maxFileSize], but only the blueimp validator enforces it.
# UploadsController accepts whatever arrives, and #handle_chunk appends CONTENT-RANGE
# chunks to a file on disk, so an ingress body-size cap bounds one request while the
# assembled file stays unbounded.
module Hyrax
  module UploadsControllerDecorator
    extend ActiveSupport::Concern

    # prepended, not included: ActiveSupport::Concern only evaluates the included
    # block from append_features, so pairing `included do` with prepend registers
    # nothing at all and the check silently never runs.
    prepended do
      before_action :enforce_upload_limit!, only: [:create]
    end

    private

    def enforce_upload_limit!
      limit = tenant_upload_limit
      return if limit.blank?

      incoming = params[:files]&.first
      # The first POST of an upload carries the filename as a String rather than a
      # file, so there is nothing to measure yet.
      return unless incoming.respond_to?(:original_filename)

      return if assembled_size(incoming) <= limit

      render_upload_too_large(limit)
    end

    # Mirrors Hyrax::UploadsController#handle_chunk: bytes are appended only when a
    # CONTENT-RANGE header starts exactly where the file on disk ends. Every other
    # path replaces the file, so the assembled size is this request alone. Counting
    # the existing bytes unconditionally would reject a legitimate replacement.
    def assembled_size(incoming)
      content_range = request.headers['CONTENT-RANGE']
      return incoming.size if params[:id].blank? || content_range.blank?

      current = bytes_already_uploaded
      begin_of_chunk = content_range[/\ (.*?)-/, 1].to_i

      begin_of_chunk == current ? current + incoming.size : incoming.size
    end

    def bytes_already_uploaded
      path = Hyrax::UploadedFile.find_by(id: params[:id])&.file&.path
      return 0 if path.blank? || !File.exist?(path)

      File.size(path)
    end

    # nil disables the check rather than rejecting everything, so a tenant with the
    # setting cleared behaves as it does today instead of losing uploads.
    def tenant_upload_limit
      # Strict, because to_i turns "5 GB" into 5 and would impose a five byte cap
      # that rejects everything. A setting we cannot read as a byte count disables
      # the check, which is the same way a blank one behaves.
      raw = Site.account&.file_size_limit.to_s.strip
      return nil unless raw.match?(/\A\d+\z/)

      limit = raw.to_i
      limit.positive? ? limit : nil
    end

    # blueimp's _onFail reads its error off the browser File object rather than the
    # response, so the browser shows the status text and this body reaches API and
    # curl callers and the logs. Kept in blueimp's files-array shape regardless.
    def render_upload_too_large(limit)
      render json: {
        files: [{
          name: params[:files]&.first&.original_filename,
          error: "File exceeds the #{ActiveSupport::NumberHelper.number_to_human_size(limit)} upload limit for this site."
        }]
      }, status: :payload_too_large
    end
  end
end

Hyrax::UploadsController.prepend(Hyrax::UploadsControllerDecorator) if defined?(Hyrax::UploadsController)
