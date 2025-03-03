# frozen_string_literal: true

module SolrDocumentDecorator
  # Custom Mobius work type fields
  def rights
    self['rights_tesim']
  end

  def coverage
    self['coverage_tesim']
  end

  def relation
    self['relation_tesim']
  end

  def file_format
    self['file_format_tesim']
  end

  # Custom Unca work type fields
  def date_published
    self['date_published_tesim']
  end

  def spatial_coverage
    self['spatial_coverage_tesim']
  end

  def temporal_coverage
    self['temporal_coverage_tesim']
  end
end

SolrDocument.prepend(SolrDocumentDecorator)
