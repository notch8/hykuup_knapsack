# frozen_string_literal: true

# OVERRIDE Hyku until 6.2 release to add patch for generating A/V ids for IIIF Manifests

module Hyrax
  module IiifAv
    module DisplaysContentDecoratorDecorator
      def video_content
        return super if stream_urls.present?

        Hyku::Application.iiif_video_labels_and_mime_types.map do |label, mime_type|
          host_with_protocol = "https://#{request.base_url}" # forces https
          mime_type = 'video/mp4' if mime_type == 'video/mpeg'
          url = Hyrax::Engine.routes.url_helpers.download_url(solr_document.id, host: host_with_protocol, file: label, mime_type:)
          video_display_content(url, label, mime_type:)
        end
      end

      def audio_content
        return super if stream_urls.present?

        Hyku::Application.iiif_audio_labels_and_mime_types.map do |label, mime_type|
          host_with_protocol = "https://#{request.base_url}" # forces https
          url = Hyrax::Engine.routes.url_helpers.download_url(solr_document.id, host: host_with_protocol, file: label, mime_type:)
          audio_display_content(url, label, mime_type:)
        end
      end
    end
  end
end

Hyrax::IiifAv::DisplaysContentDecorator.prepend(Hyrax::IiifAv::DisplaysContentDecoratorDecorator)
