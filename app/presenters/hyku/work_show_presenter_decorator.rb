# frozen_string_literal: true

# OVERRIDE Hyku to delegate Mobius properties
# OVERRIDE Hyku to delegate Unca property :date_published
Hyku::WorkShowPresenter.delegate :rights,
                                 :relation,
                                 :coverage,
                                 :file_format,
                                 :date_published,
                                 :spatial_coverage,
                                 :temporal_coverage,
                                 to: :solr_document
