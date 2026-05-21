# frozen_string_literal: true

# TEMPORARY OVERRIDE -- DELETE THIS FILE once the hyrax-webapp submodule is
# bumped to a Hyrax revision that includes samvera/hyrax#7459 (adds the
# `if resource.respond_to?(:transcript_ids)` guard upstream).
#
# Without that guard, FileSet indexing crashes for flexible-metadata tenants
# whose M3 profile does not declare a `transcript_ids` property. Every
# bulkrax file-set import hits NoMethodError at
# `hyrax/indexers/file_set_indexer.rb:27` inside `to_solr`.
#
# We can't simply `super.tap` and patch the offending line because `super`
# raises before returning. Instead, define `transcript_ids` as a singleton
# method on the resource for this indexing call (only when the resource
# doesn't already respond to it). Upstream then runs unchanged: it calls
# `resource.transcript_ids` and gets nil, so `nil&.map(&:to_s)` is nil and
# `solr_doc['transcript_ids_ssim']` is set to nil. No re-implementation.
module Hyrax
  module Indexers
    module FileSetIndexerDecorator
      def to_solr
        resource.define_singleton_method(:transcript_ids) { nil } unless resource.respond_to?(:transcript_ids)
        super
      end
    end
  end
end

Hyrax::Indexers::FileSetIndexer.prepend(Hyrax::Indexers::FileSetIndexerDecorator)
