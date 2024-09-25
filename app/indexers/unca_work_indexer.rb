# frozen_string_literal: true

# Generated via
#  `rails generate hyrax:work_resource UncaWork`
class UncaWorkIndexer < Hyrax::Indexers::PcdmObjectIndexer(UncaWork)

  include Hyrax::Indexer(:etd_resource)
  include Hyrax::Indexer(:unca_work)

  include HykuIndexing
  # Uncomment this block if you want to add custom indexing behavior:
  #  def to_solr
  #    super.tap do |index_document|
  #      index_document[:my_field_tesim]   = resource.my_field.map(&:to_s)
  #      index_document[:other_field_ssim] = resource.other_field
  #    end
  #  end
end
