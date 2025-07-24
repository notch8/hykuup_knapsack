# frozen_string_literal: true

# Generated via
#  `rails generate hyrax:work_resource UncaWork`
#  updated to only work for flexible true since app is now using flexible metadat
class UncaWorkIndexer < Hyrax::ValkyrieWorkIndexer
  include Hyrax::Indexer('UncaWork')
  include HykuIndexing
  # Uncomment this block if you want to add custom indexing behavior:
  #  def to_solr
  #    super.tap do |index_document|
  #      index_document[:my_field_tesim]   = resource.my_field.map(&:to_s)
  #      index_document[:other_field_ssim] = resource.other_field
  #    end
  #  end
end
