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

  # OVERRIDE: Hyku v6.0.0 to prevent undefined method `active_fedora_basis_path' errors
  def hydra_model(classifier: nil)
    model = first('has_model_ssim')&.safe_constantize
    # HACK: without this, #hydra_model will falsely return ActiveFedora::Base,
    # which causes numerous undefined method `active_fedora_basis_path' errors
    # related to polymorphic pathing
    return model if HYKUUP_VALKYRIE_ONLY_MODELS.include?(model)

    model = (first('has_model_ssim')&.+ 'Resource')&.safe_constantize if Hyrax.config.valkyrie_transition?
    model || model_classifier(classifier).classifier(self).best_model
  end
end

SolrDocument.prepend(SolrDocumentDecorator)
