# frozen_string_literal: true

class ScholarlyWork < Hyrax::Work
  if Hyrax.config.work_include_metadata?
    # Basic metadata has been included via :scholarly_work so we can customize it
    include Hyrax::Schema(:scholarly_work)
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
