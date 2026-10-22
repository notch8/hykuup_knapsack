# frozen_string_literal: true

require 'google/cloud/errors'

# OVERRIDE Hyrax - a Google::Cloud::Error (e.g. PermissionDeniedError when the tenant's GA property
# isn't shared with the service account) 500s the file and work stats pages. Render zeroed stats
# with a flash notice instead. Same fix as samvera/hyrax#7676 - remove once that merges and this
# app's hyrax-webapp submodule picks it up.
module Hyrax
  module StatsControllerDecorator
    def self.prepended(base)
      base.rescue_from Google::Cloud::Error, with: :analytics_unavailable
    end

    def file
      super
      @stats.to_flot # load now so a Google failure is rescued here, not mid-render
    end

    private

    def analytics_unavailable(exception)
      Rails.logger.error "Analytics error: #{exception.message}"
      flash.now[:alert] = analytics_error_message(exception)
      if action_name == 'file'
        @stats = Hyrax::FileUsage.new(params[:id]).without_analytics
      else
        @document ||= ::SolrDocument.find(params[:id])
        @pageviews = @downloads = Hyrax::Analytics::Results.new([])
      end
      render action_name
    end

    def analytics_error_message(exception)
      type = exception.is_a?(Google::Cloud::PermissionDeniedError) ? 'permission' : 'general'
      I18n.t("hyrax.admin.analytics.errors.#{type}.message")
    end
  end
end

Hyrax::StatsController.prepend(Hyrax::StatsControllerDecorator)
