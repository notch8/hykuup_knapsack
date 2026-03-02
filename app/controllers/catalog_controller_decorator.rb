# frozen_string_literal: true

module CatalogControllerDecorator
  extend ActiveSupport::Concern
end
CatalogController.prepend(CatalogControllerDecorator)

module CatalogControllerDecorator
  CatalogController.configure_blacklight do |config|
    config.advanced_search[:form_facet_partial] = "advanced_search_facets"
    key = 'identifier_tesim'
    config.index_fields.delete(key)
    config.add_index_field key, helper_method: :index_field_link, field_name: 'identifier_sim', if: :render_in_tenant?
  end
end
