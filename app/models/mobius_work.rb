# frozen_string_literal: true

# Generated via
#  `rails generate hyrax:work_resource MobiusWork`
class MobiusWork < Hyrax::Work
  if Hyrax.config.work_include_metadata?
    include Hyrax::Schema(:basic_metadata)
    include Hyrax::Schema(:mobius_work)
    include Hyrax::Schema(:with_pdf_viewer)
    include Hyrax::Schema(:with_video_embed)
    prepend OrderAlready.for(:creator)
  else
    acts_as_flexible_resource

    def creator
      OrderAlready::InputOrderSerializer.deserialize(@attributes[:creator])
    end

    def creator=(values)
      set_value(:creator, OrderAlready::InputOrderSerializer.serialize(values))
    end
  end

  include Hyrax::ArResource
  include Hyrax::NestedWorks

  include IiifPrint.model_configuration(
    pdf_split_child_model: GenericWorkResource,
    pdf_splitter_service: IiifPrint::TenantConfig::PdfSplitter
  )
end
