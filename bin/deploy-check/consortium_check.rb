# Verifies consortium behaviour holds, grouped by consortium rather than by
# tenant. The general snapshot diff catches a tenant changing; this answers
# "is every Mobius tenant still coherent" - which is the question that matters
# when a deploy touches work type or metadata profile resolution.
#
#   kubectl --context <ctx> -n <ns> exec -i <pod> -- bundle exec rails runner - \
#     < bin/deploy-check/consortium_check.rb
#
# Strictly read-only. Non-zero exit if any tenant is incoherent.
problems = []
by_consortium = {}

Account.order(:name).find_each do |account|
  Apartment::Tenant.switch(account.tenant) do
    Site.reset! if Site.respond_to?(:reset!)

    consortium = account.part_of_consortia
    persisted = Array(Site.instance.available_works)
    allowed = Array(TenantWorkTypeFilter.allowed_work_types)
    profile = TenantWorkTypeFilter.tenant_metadata_profile_path('DEFAULT').to_s
    schema = Hyrax::FlexibleSchema.current_version
    schema_classes = schema ? (schema['classes'] || {}).keys : []

    # A work type offered to depositors with no class in the tenant's profile has
    # no field definitions behind it.
    orphaned = persisted.reject do |w|
      schema_classes.include?(w) || schema_classes.include?("#{w}Resource")
    end
    orphaned = [] if schema_classes.empty? # no schema loaded: different condition, not an orphan

    entry = {
      name: account.name,
      persisted: persisted.sort,
      allowed: allowed.sort,
      exceeds: (persisted - allowed).sort,
      profile: profile.split('/').last(2).join('/'),
      schema_classes: schema_classes.size,
      orphaned: orphaned.sort
    }
    (by_consortium[consortium] ||= []) << entry

    # The expected profile for a consortium tenant is that consortium's profile.
    if consortium && !profile.include?("metadata_profiles/#{consortium}/")
      problems << "#{account.name} (#{consortium}) resolves #{entry[:profile]}, expected #{consortium}/m3_profile.yaml"
    end
    problems << "#{account.name} offers #{orphaned.inspect} with no class in its profile" if orphaned.any?
  end
rescue StandardError => e
  problems << "#{account.name}: #{e.class}: #{e.message.lines.first.to_s.strip[0, 80]}"
end

by_consortium.sort_by { |k, _| k.to_s }.each do |consortium, tenants|
  label = consortium || '(none)'
  puts "=== #{label} - #{tenants.size} tenant(s) ==="
  profiles = tenants.map { |t| t[:profile] }.uniq
  puts "  profiles in use: #{profiles.inspect}#{profiles.size > 1 ? '  <-- MIXED' : ''}"
  tenants.each do |t|
    flags = []
    flags << "exceeds=#{t[:exceeds].inspect}" if t[:exceeds].any?
    flags << "orphaned=#{t[:orphaned].inspect}" if t[:orphaned].any?
    flags << 'no_schema' if t[:schema_classes].zero?
    puts format('  %-22s works=%-46s %s', t[:name], t[:persisted].inspect, flags.join(' '))
  end
end

puts "\n=== PROBLEMS (#{problems.size}) ==="
problems.each { |p| puts "  FAIL #{p}" }
puts '  none - every consortium tenant resolves its own profile' if problems.empty?
exit(problems.empty? ? 0 : 1)
