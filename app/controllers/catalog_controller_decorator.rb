# frozen_string_literal: true

module CatalogControllerDecorator
  extend ActiveSupport::Concern
end
CatalogController.prepend(CatalogControllerDecorator)

# OVERRIDE: Hyku 6.1 to support linked identifiers which contain a colon
CatalogController.configure_blacklight do |config|
  key = 'identifier_tesim'
  config.index_fields.delete(key)
  config.add_index_field key, helper_method: :index_field_link, field_name: 'identifier_sim', if: :render_in_tenant?
end
