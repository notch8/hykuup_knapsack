# frozen_string_literal: true

# OVERRIDE Hyku v7.1.0 CatalogController: link identifiers that contain a colon.
# Upstream indexes identifier_tesim against field_name: 'identifier', which breaks the link.
module CatalogControllerDecorator
  extend ActiveSupport::Concern

  prepended do
    configure_blacklight do |config|
      key = 'identifier_tesim'
      config.index_fields.delete(key)
      config.add_index_field key, helper_method: :index_field_link, field_name: 'identifier_sim', if: :render_in_tenant?
    end
  end
end

CatalogController.prepend(CatalogControllerDecorator)
