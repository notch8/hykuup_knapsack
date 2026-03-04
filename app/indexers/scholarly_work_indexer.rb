# frozen_string_literal: true

class ScholarlyWorkIndexer < Hyrax::ValkyrieWorkIndexer
  include Hyrax::Indexer('ScholarlyWork') if Hyrax.config.work_include_metadata?
  include HykuIndexing
  # check_if_flexible adds Hyrax::Indexer with M3SchemaLoader for flexible models
  check_if_flexible(ScholarlyWork)
  # Uncomment this block if you want to add custom indexing behavior:
  #  def to_solr
  #    super.tap do |index_document|
  #      index_document[:my_field_tesim]   = resource.my_field.map(&:to_s)
  #      index_document[:other_field_ssim] = resource.other_field
  #    end
  #  end
end
