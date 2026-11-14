# frozen_string_literal: true

# OVERRIDE Hyrax - zero-filled charts for when the analytics provider can't be reached.
# Same as samvera/hyrax#7676 - remove once that merges and this app's hyrax-webapp submodule picks it up.
module Hyrax
  module FileUsageDecorator
    def without_analytics
      @downloads = zero_fill([])
      @pageviews = zero_fill([])
      self
    end
  end
end

Hyrax::FileUsage.prepend(Hyrax::FileUsageDecorator)
