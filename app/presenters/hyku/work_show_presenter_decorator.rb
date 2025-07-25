# frozen_string_literal: true

# OVERRIDE Hyku to delegate Mobius properties
# OVERRIDE Hyku to delegate Scholarly Work property :date_published
Hyku::WorkShowPresenter.delegate :rights,
                                 :relation,
                                 :coverage,
                                 :file_format,
                                 :date_published,
                                 :spatial_coverage,
                                 :temporal_coverage,
                                 :format,
                                 to: :solr_document
