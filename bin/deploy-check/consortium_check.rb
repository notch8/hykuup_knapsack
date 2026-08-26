# frozen_string_literal: true

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

# A work type offered to depositors with no class in the tenant's profile has no
# field definitions behind it. A tenant with no schema at all is a different
# condition, not an orphan.
def orphaned_types(persisted, schema_classes)
  return [] if schema_classes.empty?

  persisted.reject { |w| schema_classes.include?(w) || schema_classes.include?("#{w}Resource") }
end

def tenant_facts
  Site.reset! if Site.respond_to?(:reset!)
  schema = Hyrax::FlexibleSchema.current_version
  {
    persisted: Array(Site.instance.available_works),
    allowed: Array(TenantWorkTypeFilter.allowed_work_types),
    profile: TenantWorkTypeFilter.tenant_metadata_profile_path('DEFAULT').to_s,
    schema_classes: schema ? (schema['classes'] || {}).keys : []
  }
end

def inspect_tenant(account)
  f = tenant_facts
  {
    name: account.name,
    persisted: f[:persisted].sort,
    allowed: f[:allowed].sort,
    exceeds: (f[:persisted] - f[:allowed]).sort,
    profile_full: f[:profile],
    profile: f[:profile].split('/').last(2).join('/'),
    schema_classes: f[:schema_classes].size,
    orphaned: orphaned_types(f[:persisted], f[:schema_classes]).sort
  }
end

def problems_for(account, entry)
  found = []
  consortium = account.part_of_consortia
  # The expected profile for a consortium tenant is that consortium's own.
  if consortium && !entry[:profile_full].include?("metadata_profiles/#{consortium}/")
    found << "#{account.name} (#{consortium}) resolves #{entry[:profile]}, " \
             "expected #{consortium}/m3_profile.yaml"
  end
  found << "#{account.name} offers #{entry[:orphaned].inspect} with no class in its profile" if entry[:orphaned].any?
  found
end

Account.order(:name).find_each do |account|
  entry = Apartment::Tenant.switch(account.tenant) { inspect_tenant(account) }
  (by_consortium[account.part_of_consortia] ||= []) << entry
  problems.concat(problems_for(account, entry))
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
