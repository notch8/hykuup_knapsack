# frozen_string_literal: true

# OVERRIDE Hyku v7.1.0: saves, deletes and wipes use the current thread's tenant core, not
# whichever tenant SolrEndpoint#switch! set on the shared adapter last.
# Remove once Hyku includes samvera/hyku#3394
require Rails.root.join('lib', 'valkyrie', 'indexing', 'solr', 'indexing_adapter_decorator').to_s

module Valkyrie
  module Indexing
    module Solr
      module IndexingAdapterTenantConnectionDecorator
        def connection
          ::SolrEndpoint.new.connection
        end
      end
    end
  end
end

Valkyrie::Indexing::Solr::IndexingAdapter.prepend(Valkyrie::Indexing::Solr::IndexingAdapterTenantConnectionDecorator)
