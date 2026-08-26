# frozen_string_literal: true

# Checks that A/V derivatives are present and actually playable, which the snapshot
# cannot see: it records whether a thumbnail exists, not whether a browser can start
# the video.
#
#   kubectl --context <ctx> -n <ns> exec -i <pod> -- bundle exec rails runner - \
#     < bin/deploy-check/derivative_check.rb
#
# Strictly read-only. Non-zero exit if a derivative is missing or unplayable.
#
# An mp4 whose `moov` atom follows `mdat` has its index at the end of the file.
# Safari will not begin progressive playback without reading that index first and
# will not fetch the whole file to find it, so the video fails in Safari while
# playing normally in Chrome. `ffmpeg -movflags +faststart` moves the atom to the
# front; without it a derivative inherits whatever the uploaded file had.
HEAD_BYTES = 8192

# Driven by the app's own config so this stays correct when derivative formats change.
# Keyed on :url, not :format - the thumbnail is declared as format "jpg" but written
# as `-thumbnail.jpeg`, and :url is what DerivativePath builds the filename from.
def expected_formats(kind)
  Array(Hyrax.config.derivative_options[kind]).map { |o| o[:url].to_s }.reject(&:empty?).uniq
rescue StandardError
  kind == :video ? %w[thumbnail mp4] : %w[mp3 ogg]
end

def atom_order(path)
  head = File.binread(path, HEAD_BYTES)
  moov = head.index('moov')
  mdat = head.index('mdat')
  return :faststart if moov && (mdat.nil? || moov < mdat)
  return :moov_last if mdat

  :indeterminate
rescue StandardError => e
  "ERROR: #{e.class}"
end

# Atom order only means anything for the mp4 container; mp3 and ogg stream regardless.
def check(id, format)
  path = Hyrax::DerivativePath.derivative_path_for_reference(id, format).to_s
  return :missing unless File.exist?(path)
  return :present unless format == 'mp4'

  atom_order(path)
end

problems = []
counts = Hash.new(0)

Account.order(:name).find_each do |account|
  Apartment::Tenant.switch(account.tenant) do
    { video: 'video', audio: 'audio' }.each do |kind, prefix|
      formats = expected_formats(kind)
      Hyrax::SolrService.post(q: "mime_type_ssi:#{prefix}*", rows: 25, fl: 'id')
                        .dig('response', 'docs').to_a.each do |doc|
        formats.each do |format|
          state = check(doc['id'], format)
          counts["#{format}:#{state}"] += 1
          next if %i[faststart present].include?(state)

          problems << "#{account.name} #{prefix} #{doc['id']} #{format}: #{state}"
        end
      end
    end
  end
rescue StandardError => e
  problems << "#{account.name}: #{e.class}: #{e.message.lines.first.to_s.strip[0, 70]}"
end

puts '=== A/V derivative playability ==='
counts.sort.each { |state, n| puts format('  %-22s %d', state, n) }

puts "\n=== PROBLEMS (#{problems.size}) ==="
problems.first(30).each { |p| puts "  FAIL #{p}" }
puts "  ...and #{problems.size - 30} more" if problems.size > 30
puts '  none - every A/V derivative is present, and every mp4 starts with its moov atom' if problems.empty?

puts "\nmoov_last means Safari cannot start playback while Chrome can. Fix upstream " \
     'with `-movflags +faststart` on the mp4 derivative encode, then regenerate.'
exit(problems.empty? ? 0 : 1)
