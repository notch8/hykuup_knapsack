#!/usr/bin/env ruby
# frozen_string_literal: true

# Diff two snapshot.rb captures and report what a deploy changed.
#
#   bin/deploy-check/compare.rb before.json after.json
#
# Exits 1 when anything in CRITICAL moved, so this can gate a deploy. Counts are
# reported but never fail the run, since content changes while a deploy is in flight.
#
# Runs standalone under plain ruby, so no ActiveSupport here.
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

def index_samples(entry)
  Array(entry['sample_works']).each_with_object({}) do |sample, acc|
    acc[sample['id']] = sample if sample.is_a?(Hash)
  end
end

def compare_global(before, after)
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
  [problems, notes]
end

def compare_roster(btenants, atenants)
  problems = []
  notes = []
  missing = (btenants.keys - atenants.keys).sort
  added = (atenants.keys - btenants.keys).sort
  problems << "tenants disappeared: #{missing.inspect}" if missing.any?
  notes << "tenants added: #{added.inspect}" if added.any?
  [problems, notes]
end

# A work that had a thumbnail and lost it is a derivative regression.
def compare_thumbnails(name, before, after)
  asamples = index_samples(after)
  index_samples(before).filter_map do |id, bsample|
    asample = asamples[id]
    next unless asample && bsample['has_thumbnail'] && !asample['has_thumbnail']

    "#{name}: work #{id} lost its thumbnail"
  end
end

def compare_tenant(name, before, after)
  return [["#{name}: now erroring - #{after['ERROR']}"], []] if after.key?('ERROR') && !before.key?('ERROR')

  problems = []
  notes = []

  CRITICAL.each do |key|
    next if before[key] == after[key]

    if errored?(before[key])
      notes << "#{name}.#{key}: was unreadable before, now #{after[key].inspect}"
    else
      problems << "#{name}.#{key}: #{before[key].inspect} -> #{after[key].inspect}"
    end
  end

  INFORMATIONAL.each { |key| notes << "#{name}.#{key} changed" if before[key] != after[key] }

  [problems + compare_thumbnails(name, before, after), notes]
end

def compare(before, after)
  problems, notes = compare_global(before, after)

  btenants = before.fetch('tenants', {})
  atenants = after.fetch('tenants', {})
  roster_problems, roster_notes = compare_roster(btenants, atenants)
  problems += roster_problems
  notes += roster_notes

  (btenants.keys & atenants.keys).sort.each do |name|
    tenant_problems, tenant_notes = compare_tenant(name, btenants[name], atenants[name])
    problems += tenant_problems
    notes += tenant_notes
  end

  [problems, notes]
end

def report(problems, notes)
  puts "=== REGRESSIONS (#{problems.size}) ==="
  problems.each { |p| puts "  FAIL #{p}" }
  puts '  none - nothing in the must-not-change set moved' if problems.empty?

  puts "\n=== INFORMATIONAL (#{notes.size}) ==="
  notes.first(40).each { |n| puts "  note #{n}" }
  puts "  ... and #{notes.size - 40} more" if notes.size > 40
end

abort "usage: #{$PROGRAM_NAME} before.json after.json" unless ARGV.length == 2

problems, notes = compare(JSON.parse(File.read(ARGV[0])), JSON.parse(File.read(ARGV[1])))
report(problems, notes)
exit(problems.empty? ? 0 : 1)
