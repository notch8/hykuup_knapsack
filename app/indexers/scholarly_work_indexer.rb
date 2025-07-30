# frozen_string_literal: true

# Copied from UncaWorkIndexer as part of renaming UncaWork to ScholarlyWork
class ScholarlyWorkIndexer < Hyrax::ValkyrieWorkIndexer
  # Basic metadata has been included via :scholarly_work so we can customize it
  # include Hyrax::Indexer(:basic_metadata) unless Hyrax.config.flexible?
  include Hyrax::Indexer(:scholarly_work) unless Hyrax.config.flexible?
  include Hyrax::Indexer(:with_pdf_viewer) unless Hyrax.config.flexible?
  include Hyrax::Indexer(:with_video_embed) unless Hyrax.config.flexible?

  include Hyrax::Indexer('ScholarlyWork') if Hyrax.config.flexible?
  include HykuIndexing
  # Uncomment this block if you want to add custom indexing behavior:
  #  def to_solr
  #    super.tap do |index_document|
  #      index_document[:my_field_tesim]   = resource.my_field.map(&:to_s)
  #      index_document[:other_field_ssim] = resource.other_field
  #    end
  #  end
end
