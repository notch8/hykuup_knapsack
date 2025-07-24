# frozen_string_literal: true

# Generated via
#  `rails generate hyrax:work_resource MobiusWork`
#  updated to only work for flexible true since app is now using flexible metadat
class MobiusWork < Hyrax::Work
  include Hyrax::ArResource
  include Hyrax::NestedWorks
  # include specifically so specs will include it, as flexible? was false in hyrax's code
  # in the Resource module, resulting in unexpected behavior for the specs.
  include Hyrax::Flexibility

  include IiifPrint.model_configuration(
    pdf_split_child_model: GenericWorkResource,
    pdf_splitter_service: IiifPrint::TenantConfig::PdfSplitter
  )
end
