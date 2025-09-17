# frozen_string_literal: true

module ApplicationControllerDecorator
  extend ActiveSupport::Concern

  included do
    prepend_before_action :set_locale_from_params
  end

  private

  def set_locale_from_params
    # Set locale from params or fall back to default
    I18n.locale = params[:locale] || I18n.default_locale
  end

  def default_url_options
    # Ensure all generated URLs include the current locale
    super.merge(locale: I18n.locale)
  end
end

ApplicationController.include(ApplicationControllerDecorator)
