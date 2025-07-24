# frozen_string_literal: true

# Copied from UncaWorkIndexer as part of renaming UncaWork to ScholarlyWork
class ScholarlyWorkIndexer < Hyrax::ValkyrieWorkIndexer
  include Hyrax::Indexer('ScholarlyWork')
  include HykuIndexing
  # Uncomment this block if you want to add custom indexing behavior:
  #  def to_solr
  #    super.tap do |index_document|
  #      index_document[:my_field_tesim]   = resource.my_field.map(&:to_s)
  #      index_document[:other_field_ssim] = resource.other_field
  #    end
  #  end
end
