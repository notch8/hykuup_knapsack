# frozen_string_literal: true

# OVERRIDE Hyrax v5.3.0 - route audio and video without a derivative to type
# icons rather than the generic document icon.
module Hyrax
  module ThumbnailPathServiceMediaDecorator
    AUDIO_EXTENSIONS = %w[mp3 wav flac ogg oga m4a aac wma aiff].freeze
    VIDEO_EXTENSIONS = %w[mp4 mov avi mkv webm m4v mpeg mpg wmv ogv].freeze

    def call(object)
      path = super
      # A default_work_image the admin chose deliberately outranks a type icon.
      return path unless path == default_image && Site.instance.default_work_image&.url.blank?

      file_set = media_file_set_for(object)
      return path unless file_set

      case media_kind(file_set)
      when :audio then audio_image
      when :video then media_image
      else path
      end
    end

    def media_image
      ActionController::Base.helpers.image_path('hyku_knapsack/media.svg')
    end

    private

    # @return [Hyrax::FileSet, nil] the file set the thumbnail resolves to
    def media_file_set_for(object)
      return object if object.try(:file_set?)
      return nil if object.try(:thumbnail_id).blank?

      thumb = fetch_thumbnail(object)
      thumb if thumb.try(:file_set?)
    end

    # @return [:audio, :video, nil]
    def media_kind(file_set)
      service = Hyrax::FileSetTypeService.new(file_set: file_set)
      return :audio if service.audio?
      return :video if service.video?

      kind_from_extension(file_set, service)
    end

    # mime_type is FileMetadata::GENERIC_MIME_TYPE until characterization runs,
    # so it cannot distinguish audio from video during the import window.
    def kind_from_extension(file_set, service)
      name = file_set.label.presence || service.metadata&.original_filename
      extension = File.extname(name.to_s).delete('.').downcase
      return :audio if AUDIO_EXTENSIONS.include?(extension)
      return :video if VIDEO_EXTENSIONS.include?(extension)

      nil
    end
  end
end

Hyrax::ThumbnailPathService.singleton_class.send(:prepend, Hyrax::ThumbnailPathServiceMediaDecorator)
