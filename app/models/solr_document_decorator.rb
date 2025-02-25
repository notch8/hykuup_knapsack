# frozen_string_literal: true

module SolrDocumentDecorator
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
end

SolrDocument.prepend(SolrDocumentDecorator)
