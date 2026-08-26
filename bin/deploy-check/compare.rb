#!/usr/bin/env ruby
# frozen_string_literal: true

# Diff two snapshot.rb captures and report what a deploy changed.
#
#   bin/deploy-check/compare.rb before.json after.json
#
# Exits 1 when anything in CRITICAL moved, so this can gate a deploy. Counts are
# reported but never fail the run, since content changes while a deploy is in flight.
require 'json'

# A change here is a regression signal, not normal drift.
CRITICAL = %w[available_works consortia profile_path themes schema_classes features].freeze
# Reported for awareness; these move on their own.
INFORMATIONAL = %w[counts vocabularies schema_version sample_works
                   allowed_by_consortium pending_migrations].freeze
# Intended to move when the submodule is bumped.
EXPECTED_GLOBAL_CHANGES = %w[hyrax_version puma_version].freeze

# A key the previous version could not even report cannot have regressed.
def errored?(value)
  value.is_a?(String) && value.start_with?('ERROR:')
end

def compare(before, after)
  problems = []
  notes = []

  before.fetch('global', {}).each do |key, bval|
    aval = after.dig('global', key)
    next if bval == aval

    line = "global.#{key}: #{bval.inspect} -> #{aval.inspect}"
    if EXPECTED_GLOBAL_CHANGES.include?(key) || errored?(bval)
      notes << line
    else
      problems << line
    end
  end

  btenants = before.fetch('tenants', {})
  atenants = after.fetch('tenants', {})

  missing = (btenants.keys - atenants.keys).sort
  added = (atenants.keys - btenants.keys).sort
  problems << "tenants disappeared: #{missing.inspect}" if missing.any?
  notes << "tenants added: #{added.inspect}" if added.any?

  (btenants.keys & atenants.keys).sort.each do |name|
    b = btenants[name]
    a = atenants[name]

    if a.key?('ERROR') && !b.key?('ERROR')
      problems << "#{name}: now erroring - #{a['ERROR']}"
      next
    end

    CRITICAL.each do |key|
      next if b[key] == a[key]

      problems << if errored?(b[key])
                    nil
                  else
                    "#{name}.#{key}: #{b[key].inspect} -> #{a[key].inspect}"
                  end
      notes << "#{name}.#{key}: was unreadable before, now #{a[key].inspect}" if errored?(b[key])
    end
    problems.compact!

    INFORMATIONAL.each { |key| notes << "#{name}.#{key} changed" if b[key] != a[key] }

    # A work that had a thumbnail and lost it is a derivative regression.
    bsamples = Array(b['sample_works']).select { |s| s.is_a?(Hash) }.to_h { |s| [s['id'], s] }
    asamples = Array(a['sample_works']).select { |s| s.is_a?(Hash) }.to_h { |s| [s['id'], s] }
    bsamples.each do |id, bs|
      as = asamples[id]
      next unless as && bs['has_thumbnail'] && !as['has_thumbnail']

      problems << "#{name}: work #{id} lost its thumbnail"
    end
  end

  [problems, notes]
end

abort "usage: #{$PROGRAM_NAME} before.json after.json" unless ARGV.length == 2

problems, notes = compare(JSON.parse(File.read(ARGV[0])), JSON.parse(File.read(ARGV[1])))

puts "=== REGRESSIONS (#{problems.size}) ==="
problems.each { |p| puts "  FAIL #{p}" }
puts '  none - nothing in the must-not-change set moved' if problems.empty?

puts "\n=== INFORMATIONAL (#{notes.size}) ==="
notes.first(40).each { |n| puts "  note #{n}" }
puts "  ... and #{notes.size - 40} more" if notes.size > 40

exit(problems.empty? ? 0 : 1)
