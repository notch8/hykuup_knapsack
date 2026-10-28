# frozen_string_literal: true

# OVERRIDE Hyku v7.1.0 - keep hand-picked video thumbnails across a demo reset.
#
# The reimport gives every work a new file set, whose video processing writes
# its own thumbnail hours after the reset returns. The snapshot copies each
# video work's thumbnail aside, and a job puts it back once that processing
# has written the new one.
module DemoTenantResetServiceVideoThumbnailsDecorator
  # Copies land in a fresh folder first, so a failed recapture keeps the last good one.
  def snapshot!(**)
    capture_dir = thumbnail_snapshot_root.join(SecureRandom.uuid)
    begin
      thumbnails = within_tenant { capture_video_thumbnails(capture_dir) }
      snap = super
      snap['video_thumbnails'] = thumbnails
      account.update!(demo_tenant_snapshot: snap)
    rescue StandardError
      FileUtils.rm_rf(capture_dir)
      raise
    end
    prune_thumbnail_snapshots!(keep: capture_dir)
    log "captured #{thumbnails.size} video thumbnails"
    snap
  end

  private

  def restore_featured_works!
    super
    entries = Array(account.demo_tenant_snapshot['video_thumbnails'])
    return if entries.empty?

    ShowcaseThumbnailRestoreJob.perform_later(entries)
    log "queued #{entries.size} video thumbnails to restore once their videos are processed"
  end

  def thumbnail_snapshot_root
    Pathname(Hyrax.config.branding_path).join('demo-thumbnails', account.tenant.to_s)
  end

  def prune_thumbnail_snapshots!(keep:)
    return unless thumbnail_snapshot_root.exist?

    thumbnail_snapshot_root.children.each { |dir| FileUtils.rm_rf(dir) unless dir == keep }
  rescue SystemCallError => e
    log("could not clear older thumbnail copies: #{e.message}", level: :warn)
  end

  def capture_video_thumbnails(dir)
    Hyku::Application.work_types.flat_map { |model| Hyrax.query_service.find_all_of_model(model:).to_a }
                     .filter_map do |work|
      identifier = work_identifier(work)
      source = identifier && video_thumbnail_path(work)
      next unless source

      copy = dir.join("#{work.id}#{File.extname(source)}")
      FileUtils.mkdir_p(dir)
      FileUtils.cp(source, copy)
      { 'identifier' => identifier.to_s, 'file' => copy.to_s }
    end
  end

  def video_thumbnail_path(work)
    file_set = work.try(:thumbnail_id) && find_resource(work.thumbnail_id)
    return unless file_set

    original = Hyrax.custom_queries.find_original_file(file_set:)
    return unless original.mime_type.to_s.start_with?('video/')

    path = Hyrax::DerivativePath.derivative_path_for_reference(file_set.id.to_s, 'thumbnail')
    path if File.exist?(path)
  rescue Valkyrie::Persistence::ObjectNotFoundError
    nil
  end
end

DemoTenantResetService.prepend(DemoTenantResetServiceVideoThumbnailsDecorator)
