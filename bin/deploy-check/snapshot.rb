# Captures per-tenant behaviour as JSON so a post-deploy run can be diffed
# against a pre-deploy run. Strictly read-only.
#
#   kubectl --context <ctx> -n <ns> exec -i <pod> -- bundle exec rails runner - < snapshot.rb > before.json
#
# Everything here is a value a deploy could plausibly change without anyone
# noticing: work types, themes, profiles, counts, feature flags, schema version.
require 'json'

def safe(default = nil)
  yield
rescue StandardError => e
  "ERROR: #{e.class}: #{e.message.lines.first.to_s.strip[0, 80]}"
ensure
  nil
end

snapshot = {
  'global' => {
    'account_count' => safe { Account.count },
    'registered_work_types' => safe { Hyrax.config.registered_curation_concern_types.sort },
    'realtime_notifications' => safe { Hyrax.config.realtime_notifications? },
    'iiif_av_viewer' => safe { Hyrax.config.iiif_av_viewer.to_s },
    'iiif_manifest_factory' => safe { Hyrax.config.iiif_manifest_factory.to_s },
    'derivative_labels' => safe {
      Hyrax.config.derivative_options.transform_values { |v| Array(v).map { |o| o[:label].to_s }.sort }
    },
    'consortia_defined' => safe { defined?(Consortium) ? Consortium.identifiers.sort : nil },
    'puma_version' => safe { Puma::Const::PUMA_VERSION },
    'hyrax_version' => safe { Hyrax::VERSION }
  },
  'tenants' => {}
}

Account.order(:name).find_each do |account|
  entry = { 'consortia' => account.part_of_consortia }
  begin
    Apartment::Tenant.switch(account.tenant) do
      Site.reset! if Site.respond_to?(:reset!)
      site = Site.instance

      entry['available_works'] = Array(site.available_works).sort
      entry['allowed_by_consortium'] = safe { Array(TenantWorkTypeFilter.allowed_work_types).sort }
      entry['profile_path'] = safe {
        TenantWorkTypeFilter.tenant_metadata_profile_path('DEFAULT').to_s.split('/').last(2).join('/')
      }
      entry['themes'] = {
        'home' => site.home_theme, 'show' => site.show_theme, 'search' => site.search_theme
      }
      entry['schema_classes'] = safe {
        s = Hyrax::FlexibleSchema.current_version
        s ? (s['classes'] || {}).keys.sort : []
      }
      entry['schema_version'] = safe { Hyrax::FlexibleSchema.current_schema_id.to_s }
      entry['vocabularies'] = safe {
        Qa::LocalAuthority.order(:name).pluck(:name).zip(
          Qa::LocalAuthority.order(:name).map { |a| a.local_authority_entries.count }
        ).to_h
      }
      entry['counts'] = safe {
        {
          'works' => Hyrax::SolrService.post(q: 'has_model_ssim:* AND -has_model_ssim:FileSet AND -has_model_ssim:*Collection*', rows: 0)
                                       .dig('response', 'numFound'),
          'filesets' => Hyrax::SolrService.post(q: 'has_model_ssim:FileSet OR has_model_ssim:"Hyrax::FileSet"', rows: 0)
                                          .dig('response', 'numFound'),
          'users' => User.count
        }
      }
      entry['features'] = safe {
        Flipflop::FeatureSet.current.features.to_h { |f| [f.key.to_s, Flipflop.enabled?(f.key)] }
      }
      # A sample public work per tenant, so a post-deploy run can re-fetch the
      # same ids and confirm they still render with the same derivatives.
      entry['sample_works'] = safe {
        Hyrax::SolrService.post(q: 'visibility_ssi:open AND -has_model_ssim:FileSet', rows: 3,
                                fl: 'id,has_model_ssim,thumbnail_path_ss', sort: 'system_create_dtsi asc')
                          .dig('response', 'docs').to_a
                          .map { |d| { 'id' => d['id'], 'model' => Array(d['has_model_ssim']).first,
                                       'has_thumbnail' => Array(d['thumbnail_path_ss']).first.present? } }
      }
      entry['pending_migrations'] = safe {
        ActiveRecord::Base.connection.migration_context.needs_migration?
      }
    end
  rescue StandardError => e
    entry['ERROR'] = "#{e.class}: #{e.message.lines.first.to_s.strip[0, 100]}"
  end
  snapshot['tenants'][account.name] = entry
end

puts JSON.pretty_generate(snapshot)
