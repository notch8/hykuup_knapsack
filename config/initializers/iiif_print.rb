# frozen_string_literal: true

# Patch IiifPrint::PersistenceLayer::ValkyrieAdapter to skip form decoration
# when Hyrax flexible metadata is enabled. In flexible mode the
# `Hyrax::FormFields(:child_works_from_pdf_splitting)` include is a no-op, but
# the upstream code still calls `"#{work_type}Form".constantize unconditionally,
# which causes a circular autoload error when a model is loaded before its form.
IiifPrint::PersistenceLayer::ValkyrieAdapter.singleton_class.prepend(
  Module.new do
    def decorate_form_with_adapter_logic(work_type:)
      return if Hyrax.config.try(:flexible?)
      super
    end
  end
)
