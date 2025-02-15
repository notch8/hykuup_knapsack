# All newly-generated work types should be added to this list
# @see SolrDocumentDecorator#hydra_model
Rails.application.config.after_initialize do
  HYKUUP_VALKYRIE_ONLY_MODELS = [MobiusWork, UncaWork]
end
