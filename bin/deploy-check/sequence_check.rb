# frozen_string_literal: true

# Is any tenant's id sequence behind max(id)? If so, the next insert reuses an
# existing id and Postgres raises PG::UniqueViolation on the primary key.
# Read-only: reads sequence state without consuming a value (last_value, not nextval).
TABLES = %w[hyrax_flexible_schemas qa_local_authorities qa_local_authority_entries].freeze

behind = []

Account.order(:name).find_each do |account|
  Apartment::Tenant.switch(account.tenant) do
    conn = ActiveRecord::Base.connection
    TABLES.each do |table|
      next unless conn.table_exists?(table)

      max_id = conn.select_value("SELECT COALESCE(MAX(id), 0) FROM #{table}").to_i
      seq = conn.select_value("SELECT pg_get_serial_sequence('#{table}', 'id')")
      next if seq.nil?

      # last_value is only meaningful once the sequence has been used; is_called
      # tells us whether it has.
      row = conn.select_one("SELECT last_value, is_called FROM #{seq}")
      last = row['last_value'].to_i
      called = row['is_called']
      # Next value the sequence will hand out.
      nxt = called ? last + 1 : last
      status = nxt <= max_id ? 'BEHIND' : 'ok'
      behind << [account.name, table, max_id, nxt] if status == 'BEHIND'
      puts format('%-6s %-20s %-30s max_id=%-6d next=%-6d rows=%d', status, account.name, table,
                  max_id, nxt, conn.select_value("SELECT COUNT(*) FROM #{table}").to_i)
    end
  end
rescue StandardError => e
  puts "ERR    #{account.name}: #{e.class}: #{e.message.lines.first.to_s.strip[0, 70]}"
end

puts "\nSUMMARY #{behind.size} sequence(s) behind max(id)"
behind.each { |n, t, m, x| puts "  WOULD_COLLIDE #{n}.#{t}: next=#{x} but max_id=#{m}" }
