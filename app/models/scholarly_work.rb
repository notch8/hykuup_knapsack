# frozen_string_literal: true

class ScholarlyWork < Hyrax::Work
  # Basic metadata has been included via :scholarly_work so we can customize it
  # include Hyrax::Schema(:basic_metadata) unless Hyrax.config.flexible?
  include Hyrax::Schema(:scholarly_work) unless Hyrax.config.flexible?
  include Hyrax::Schema(:with_pdf_viewer) unless Hyrax.config.flexible?
  include Hyrax::Schema(:with_video_embed) unless Hyrax.config.flexible?
  include Hyrax::ArResource
  include Hyrax::NestedWorks
  # include specifically so specs will include it, as flexible? was false in hyrax's code
  # in the Resource module, resulting in unexpected behavior for the specs.
  include Hyrax::Flexibility if Hyrax.config.flexible?

  include IiifPrint.model_configuration(
    pdf_split_child_model: GenericWorkResource,
    pdf_splitter_service: IiifPrint::TenantConfig::PdfSplitter
  )

  prepend OrderAlready.for(:creator) unless Hyrax.config.flexible?
end
