# frozen_string_literal: true

# Generated via
#  `rails generate hyrax:work_resource UncaWork`
class UncaWork < Hyrax::Work
  # Basic metadata has been included via :unca_work so we can customize it
  # include Hyrax::Schema(:basic_metadata)
  include Hyrax::Schema(:unca_work) unless Hyrax.config.flexible?
  include Hyrax::Schema(:with_pdf_viewer) unless Hyrax.config.flexible?
  include Hyrax::Schema(:with_video_embed) unless Hyrax.config.flexible?
  include Hyrax::ArResource
  include Hyrax::NestedWorks

  include IiifPrint.model_configuration(
    pdf_split_child_model: GenericWorkResource,
    pdf_splitter_service: IiifPrint::TenantConfig::PdfSplitter
  )

  prepend OrderAlready.for(:creator) unless Hyrax.config.flexible?
end
