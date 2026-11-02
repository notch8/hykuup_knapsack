# frozen_string_literal: true

# OVERRIDE Hyku v7.1.0 - link reimported captions to their audio and video.
#
# The seed import attaches caption files but cannot point the media at them,
# since file set ids only exist after it, so a job links them once ingested.
module DemoTenantResetServiceCaptionsDecorator
  private

  def import_seed!
    super
    DemoCaptionLinkJob.perform_later
    log 'queued caption linking for once the imported files are ingested'
  end
end

DemoTenantResetService.prepend(DemoTenantResetServiceCaptionsDecorator)
