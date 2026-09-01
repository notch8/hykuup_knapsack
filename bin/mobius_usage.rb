# frozen_string_literal: true
#
# Report object count + storage usage per MOBIUS tenant.
#
# Usage (from the Hyku app dir, e.g. /app/samvera/hyrax-webapp in the pod):
#
#   bundle exec rails runner bin/mobius_usage.rb
#
# Options (environment variables):
#   tenants="a.digitalmobius.org b.digitalmobius.org"  # override auto-detection with an explicit list
#   format=csv                                         # emit CSV instead of a padded table
#   all=true                                           # report ALL non-search-only tenants, not just mobius
#
# Notes:
# - Storage is the sum of `file_size_lts` (bytes) across every FileSet in the tenant.
#   That field is stored-but-not-indexed in Solr, so we page through the FileSet docs
#   and sum in Ruby (stats/range queries return nothing on it). This is the
#   ORIGINAL/primary file size only; it does NOT include derivatives, thumbnails, or
#   prior file versions, and only reflects what has been characterized + indexed.
# - "Works" counts curation-concern objects; "Files" counts FileSets that carry a size.

def human_size(bytes)
  units = %w[B KB MB GB TB PB]
  size = bytes.to_f
  unit = 0
  while size >= 1024 && unit < units.length - 1
    size /= 1024
    unit += 1
  end
  format('%.2f %s', size, units[unit])
end

def mobius_accounts
  Account.where(part_of_consortia: 'mobius')
         .or(Account.where('cname LIKE ?', '%mobius%'))
         .or(Account.where(cname: 'stephens.hykuup.com'))
end

def selected_accounts
  explicit = ENV.fetch('tenants', '').split
  return Account.where(cname: explicit) if explicit.any?
  return Account.where(search_only: false) if ENV['all'] == 'true'

  mobius_accounts.where(search_only: false)
end

# Fetch one page of FileSet docs (id + file_size_lts only) via cursorMark.
def file_set_page(cursor)
  ActiveFedora::SolrService.get(
    'has_model_ssim:FileSet OR has_model_ssim:"Hyrax::FileSet"',
    rows: 1000,
    fl: 'file_size_lts',
    sort: 'id asc',
    cursorMark: cursor
  )
end

# Sum file_size_lts (bytes) and count docs that carry a size for a page of docs.
def sum_page(docs)
  bytes = 0
  files = 0
  docs.each do |doc|
    size = doc['file_size_lts']
    size = size.first if size.is_a?(Array)
    next if size.nil?

    bytes += size.to_i
    files += 1
  end
  [bytes, files]
end

# Sum primary-file storage (bytes) and file count for the CURRENT tenant.
# file_size_lts is stored-but-NOT-indexed in the Samvera Solr schema, so it can't be
# range-queried or summed via the stats component. Page the FileSet docs with
# cursorMark (no deep-paging cost) and sum in Ruby.
def tenant_file_storage
  total_bytes = 0
  total_files = 0
  cursor = '*'
  loop do
    resp = file_set_page(cursor)
    docs = resp.dig('response', 'docs') || []
    bytes, files = sum_page(docs)
    total_bytes += bytes
    total_files += files
    next_cursor = resp['nextCursorMark']
    break if docs.empty? || next_cursor.nil? || next_cursor == cursor

    cursor = next_cursor
  end
  [total_bytes, total_files]
end

work_models = Hyrax.config.curation_concerns.map { |m| %("#{m}") }.join(' OR ')
rows = []

selected_accounts.find_each do |account|
  next if account.cname.blank?

  AccountElevator.switch!(account.cname)

  works = ActiveFedora::SolrService.count("has_model_ssim:(#{work_models})")
  bytes, files = tenant_file_storage

  rows << { cname: account.cname, works:, files:, bytes: }
  warn "processed #{account.cname} (#{works} works, #{human_size(bytes)})"
end

rows.sort_by! { |r| -r[:bytes] }

total_works = rows.sum { |r| r[:works] }
total_files = rows.sum { |r| r[:files] }
total_bytes = rows.sum { |r| r[:bytes] }

if ENV['format'] == 'csv'
  puts 'tenant,works,files,bytes,storage_human'
  rows.each { |r| puts "#{r[:cname]},#{r[:works]},#{r[:files]},#{r[:bytes]},#{human_size(r[:bytes])}" }
  puts "TOTAL,#{total_works},#{total_files},#{total_bytes},#{human_size(total_bytes)}"
else
  w = ([30] + rows.map { |r| r[:cname].length }).max
  # Format strings are held in variables so the dynamic width (#{w}) does not confuse
  # RuboCop's Lint/FormatParameterMismatch, which only analyzes literal format strings.
  head_fmt = "%-#{w}s  %8s  %8s  %14s"
  row_fmt = "%-#{w}s  %8d  %8d  %14s"
  puts format(head_fmt, 'TENANT', 'WORKS', 'FILES', 'STORAGE')
  puts '-' * (w + 38)
  rows.each do |r|
    puts format(row_fmt, r[:cname], r[:works], r[:files], human_size(r[:bytes]))
  end
  puts '-' * (w + 38)
  puts format(row_fmt, "TOTAL (#{rows.size} tenants)", total_works, total_files, human_size(total_bytes))
end
