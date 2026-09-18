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

    included do
      before_action :enforce_upload_limit!, only: [:create]
    end

    private

    # Rejects a chunk that would take the assembled file past the tenant's limit,
    # counting bytes already on disk rather than the size of this request alone.
    def enforce_upload_limit!
      limit = tenant_upload_limit
      return if limit.blank?

      incoming = params[:files]&.first
      return if incoming.blank?

      return if incoming.size.to_i + bytes_already_uploaded <= limit

      render_upload_too_large(limit)
    end

    def bytes_already_uploaded
      return 0 if params[:id].blank?

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

    # blueimp reads the error off each file entry; a bare 413 renders as a silent failure.
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
