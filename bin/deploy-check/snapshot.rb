# frozen_string_literal: true
# Captures per-tenant behaviour as JSON so a post-deploy run can be diffed
# against a pre-deploy run. Strictly read-only.
#
#   kubectl --context <ctx> -n <ns> exec -i <pod> -- bundle exec rails runner - < snapshot.rb > before.json
#
# Everything here is a value a deploy could plausibly change without anyone
# noticing: work types, themes, profiles, counts, feature flags, schema version.
require 'json'

def safe(_default = nil)
  yield
rescue StandardError => e
  "ERROR: #{e.class}: #{e.message.lines.first.to_s.strip[0, 80]}"
ensure
  nil
end

# This Solr config returns 0 for `a OR b` even where each side alone matches, so
# every count is a single-clause query summed in Ruby. Colons in a model name have
# to be escaped or the term is read as a field.
def solr_count(model)
  Hyrax::SolrService.post(q: "has_model_ssim:#{model.gsub(':') { '\\:' }}", rows: 0)
                    .dig('response', 'numFound').to_i
end

# Counting "everything that is not a FileSet or Collection" also counts
# FileMetadata, ACLs and containers, which inflates the total by an order of
# magnitude. Only registered work types are works.
WORK_MODELS = lambda do
  Hyrax.config.registered_curation_concern_types.flat_map { |m| [m, "#{m}Resource"] }
end

snapshot = {
  'global' => {
    'account_count' => safe { Account.count },
    'registered_work_types' => safe { Hyrax.config.registered_curation_concern_types.sort },
    'realtime_notifications' => safe { Hyrax.config.realtime_notifications? },
    'iiif_av_viewer' => safe { Hyrax.config.iiif_av_viewer.to_s },
    'iiif_manifest_factory' => safe { Hyrax.config.iiif_manifest_factory.to_s },
    'derivative_labels' => safe do
      Hyrax.config.derivative_options.transform_values { |v| Array(v).map { |o| o[:label].to_s }.sort }
    end,
    'consortia_defined' => safe { defined?(Consortium) ? Consortium.identifiers.sort : nil },
    'puma_version' => safe { Puma::Const::PUMA_VERSION },
    'hyrax_version' => safe { Hyrax::VERSION }
  },
  'tenants' => {}
}
# rubocop:disable Metrics/BlockLength
Account.order(:name).find_each do |account|
  # part_of_consortia is a HykuUp addition; other knapsacks will not have the column.
  entry = { 'consortia' => (account.part_of_consortia if account.respond_to?(:part_of_consortia)) }
  begin
    Apartment::Tenant.switch(account.tenant) do
      Site.reset! if Site.respond_to?(:reset!)
      site = Site.instance

      entry['available_works'] = Array(site.available_works).sort
      # TenantWorkTypeFilter is a HykuUp addition; a knapsack without it simply has
      # no consortium-derived work type list or per-consortium profile to record.
      if defined?(TenantWorkTypeFilter)
        entry['allowed_by_consortium'] = safe { Array(TenantWorkTypeFilter.allowed_work_types).sort }
        entry['profile_path'] = safe do
          TenantWorkTypeFilter.tenant_metadata_profile_path('DEFAULT').to_s.split('/').last(2).join('/')
        end
      end
      entry['themes'] = {
        'home' => site.home_theme, 'show' => site.show_theme, 'search' => site.search_theme
      }
      entry['schema_classes'] = safe do
        s = Hyrax::FlexibleSchema.current_version
        s ? (s['classes'] || {}).keys.sort : []
      end
      entry['schema_version'] = safe { Hyrax::FlexibleSchema.current_schema_id.to_s }
      entry['vocabularies'] = safe do
        Qa::LocalAuthority.order(:name).pluck(:name).zip(
          Qa::LocalAuthority.order(:name).map { |a| a.local_authority_entries.count }
        ).to_h
      end
      entry['counts'] = safe do
        {
          'works' => WORK_MODELS.call.sum { |m| solr_count(m) },
          'filesets' => solr_count('FileSet') + solr_count('Hyrax::FileSet'),
          'users' => User.count
        }
      end
      entry['features'] = safe do
        Flipflop::FeatureSet.current.features.to_h { |f| [f.key.to_s, Flipflop.enabled?(f.key)] }
      end
      # A sample public work per tenant, so a post-deploy run can re-fetch the
      # same ids and confirm they still render with the same derivatives.
      entry['sample_works'] = safe do
        models = WORK_MODELS.call
        # Over-fetch and filter in Ruby: the query cannot OR the work models together,
        # and without that filter the first rows back are ACLs and file metadata.
        Hyrax::SolrService.post(q: 'visibility_ssi:open AND -has_model_ssim:FileSet', rows: 50,
                                fl: 'id,has_model_ssim,thumbnail_path_ss', sort: 'system_create_dtsi asc')
                          .dig('response', 'docs').to_a
                          .select { |d| Array(d['has_model_ssim']).any? { |m| models.include?(m) } }
                          .first(3)
                          .map do |d|
          { 'id' => d['id'], 'model' => Array(d['has_model_ssim']).first,
            'has_thumbnail' => Array(d['thumbnail_path_ss']).first.present? }
        end
      end
      # migration_context moved from the connection to the pool in newer Rails, so
      # try both rather than recording an error on whichever side of that we land.
      entry['pending_migrations'] = safe do
        pool = ActiveRecord::Base.connection_pool
        ctx = if pool.respond_to?(:migration_context)
                pool.migration_context
              elsif ActiveRecord::Base.connection.respond_to?(:migration_context)
                ActiveRecord::Base.connection.migration_context
              end
        ctx&.needs_migration?
      end
    end
  rescue StandardError => e
    entry['ERROR'] = "#{e.class}: #{e.message.lines.first.to_s.strip[0, 100]}"
  end
  snapshot['tenants'][account.name] = entry
end
# rubocop:enable Metrics/BlockLength

puts JSON.pretty_generate(snapshot)
