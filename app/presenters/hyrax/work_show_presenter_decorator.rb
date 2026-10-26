# frozen_string_literal: true

# OVERRIDE Hyku 198f495 (Hyku::WorkShowPresenter's Hyrax::WorkShowPresenter#page_title):
# end work page titles with the tenant's application name. Hyku ends them with
# hyrax.product_name so one consortium brand covers every tenant; each HykuUp tenant
# is its own brand, so it falls back to the product name only when no name is set.
module Hyrax
  module WorkShowPresenterDecorator
    def page_title
      parts = [title.first, "ID: #{id}", Site.application_name.presence || I18n.t('hyrax.product_name')]
      parts.unshift(human_readable_type) unless human_readable_type == 'Generic Work'
      parts.join(' | ')
    end
  end
end

Hyrax::WorkShowPresenter.prepend(Hyrax::WorkShowPresenterDecorator)
