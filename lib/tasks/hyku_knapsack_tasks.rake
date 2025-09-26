# frozen_string_literal: true

# rubocop:disable Metrics/BlockLength
namespace :hykuup do
  namespace :mobius do
    desc 'Update Bulkrax field mappings across all Mobius tenants'
    task update_field_mappings: :environment do
      mobius_tenants = Account.where('cname LIKE ?', '%mobius%').or(Account.where(cname: 'stephens.hykuup.com'))
      mobius_split_pattern = /\s*(?<!\\)[,|]\s*/
      mobius_csv_mappings = {
        'contributor' => { 'from' => %w[sm_contributor contributor], 'split' => mobius_split_pattern },
        'creator' => { 'from' => %w[sm_creator creator], 'split' => mobius_split_pattern },
        'date_created' => { 'from' => %w[sm_date date_created], 'split' => mobius_split_pattern },
        'description' => { 'from' => %w[tm_description description], 'split' => mobius_split_pattern },
        'identifier' => { 'from' => %w[identifier], 'split' => mobius_split_pattern, 'source_identifier' => true },
        'language' => { 'from' => %w[sm_language language], 'split' => mobius_split_pattern },
        'parents' => { 'from' => %w[sm_collection parents], 'split' => mobius_split_pattern, 'related_parents_field_mapping' => true },
        'publisher' => { 'from' => %w[sm_publisher publisher], 'split' => mobius_split_pattern },
        'resource_type' => { 'from' => %w[sm_type resource_type], 'split' => mobius_split_pattern },
        'source' => { 'from' => %w[sm_source source], 'split' => mobius_split_pattern },
        'subject' => { 'from' => %w[sm_subject subject], 'split' => mobius_split_pattern },
        'title' => { 'from' => %w[sm_title title], 'split' => mobius_split_pattern },
        # Custom property mappings
        'coverage' => { 'from' => %w[sm_coverage coverage], 'split' => mobius_split_pattern },
        'file_format' => { 'from' => %w[sm_format file_format], 'split' => mobius_split_pattern },
        'relation' => { 'from' => %w[sm_relation relation], 'split' => mobius_split_pattern },
        'rights' => { 'from' => %w[sm_rights rights], 'split' => mobius_split_pattern }
      }

      mobius_tenants.each do |account|
        switch!(account)
        field_mappings = JSON.parse(account.bulkrax_field_mappings)

        field_mappings['Bulkrax::CsvParser'].merge!(mobius_csv_mappings)
        field_mappings['Bulkrax::CsvParser'].each do |field, _settings|
          field_mappings['Bulkrax::CsvParser'][field]['split'] = mobius_split_pattern
        end

        account.bulkrax_field_mappings = field_mappings.to_json
        account.save!
      end
    end
  end

  namespace :wcu do
    desc 'Update Bulkrax field mappings across WCU/UNCA tenants'
    task update_field_mappings: :environment do
      wcu_tenants = Account.where('cname LIKE ?', '%unca%').or(Account.where(cname: 'wcu.hykuup.com'))
      wcu_split_pattern = /\s*[|]\s*/
      wcu_csv_mappings = {
        'file' => { 'from' => %w[file_name file], 'split' => wcu_split_pattern },
        'date_published' => { 'from' => %w[date_issued date_published], 'split' => wcu_split_pattern },
        'degree_discipline' => { 'from' => %w[discipline degree_discipline], 'split' => wcu_split_pattern },
        'degree_level' => { 'from' => %w[level_of_degree degree_level], 'split' => wcu_split_pattern },
        'degree_name' => { 'from' => %w[name_of_degree degree_name], 'split' => wcu_split_pattern },
        'keyword' => { 'from' => %w[keywords keyword], 'split' => wcu_split_pattern },
        'resource_type' => { 'from' => %w[type resource_type], 'split' => wcu_split_pattern }
      }

      wcu_tenants.each do |account|
        switch!(account)
        field_mappings = JSON.parse(account.bulkrax_field_mappings)

        field_mappings['Bulkrax::CsvParser'].merge!(wcu_csv_mappings)
        field_mappings['Bulkrax::CsvParser'].each do |field, _settings|
          field_mappings['Bulkrax::CsvParser'][field]['split'] = wcu_split_pattern
        end

        account.bulkrax_field_mappings = field_mappings.to_json
        account.save!
      end
    end
  end

  desc 'Migrate works from one work type to another (Usage: rake hykuup:migrate_work_class[FromWorkType,ToWorkType, tenant cname (optional)])'
  task :migrate_work_class, [:from_class, :to_class, :tenant] => :environment do |_t, args|
    tenant = args[:tenant]
    from_class = args[:from_class]
    to_class = args[:to_class]

    if from_class.blank? || to_class.blank?
      puts "Error: Both from_class and to_class must be specified"
      puts "Usage: rake hykuup:migrate_work_class[FromWorkType,ToWorkType]"
      exit 1
    end

    if from_class == to_class
      puts "Error: from_class and to_class cannot be the same"
      exit 1
    end

    begin
      # Ensure the new class is valid
      # rubocop:disable Lint/UselessAssignment
      to_class_const = to_class.constantize
      # rubocop:enable Lint/UselessAssignment

      name_list = if tenant.present?
                    [tenant]
                  else
                    Account.where.not(name: 'search').pluck(:cname)
                  end
      name_list.each do |cname|
        AccountElevator.switch!(cname)
        work_count = Valkyrie::Persistence::Postgres::ORM::Resource.where(internal_resource: from_class).count
        puts "Found #{work_count} works to migrate in tenant #{cname}"
        if work_count.zero?
          puts "No works found of type #{from_class} to migrate in tenant #{cname}"
          next
        end
        puts "Starting migration from #{from_class} to #{to_class}"

        Valkyrie::Persistence::Postgres::ORM::Resource.where(internal_resource: from_class).find_each do |work|
          puts "Migrating work #{work.id}: #{work.metadata['title']&.first}"
          work.update(internal_resource: to_class)
          # reload work
          new_work = Hyrax.query_service.find_by(id: work.id)
          Hyrax.index_adapter.save(resource: new_work)
        end
      end
      puts "Migration completed successfully"
    rescue NameError => e
      puts "invalid class name: #{e.message}"
    rescue => e
      puts "Error during migration: #{e.message}"
      puts e.backtrace.join("\n")
    end
  end

  namespace :profiles do
    desc 'Reset metadata profiles and update available works for all tenants'
    task reset_all: :environment do
      puts "\n" + "=" * 60
      puts "  RESETTING PROFILES AND AVAILABLE WORKS FOR ALL TENANTS"
      puts "=" * 60
      puts "\n⚠️  WARNING: This will overwrite ALL existing metadata profiles!"
      puts "   Custom profiles will be lost and replaced with tenant-specific defaults."
      puts "   This action cannot be undone.\n"

      print "Are you sure you want to continue? Type 'yes' to confirm: "
      confirmation = STDIN.gets.chomp

      unless confirmation.casecmp('yes').zero?
        puts "\n❌ Operation cancelled by user."
        exit 0
      end

      puts "\n✅ Confirmed. Proceeding with profile reset...\n"

      total_tenants = Account.count
      processed = 0
      errors = 0

      Account.find_each do |account|
        processed += 1
        puts "\n[#{processed}/#{total_tenants}] Processing: #{account.cname}"
        puts "  Tenant: #{account.tenant}"

        begin
          # Switch to the tenant
          Apartment::Tenant.switch!(account.tenant)

          # Reset the metadata profile
          print "  Resetting profile... "
          Hyrax::FlexibleSchema.create_default_schema
          puts "✓"

          # Update available works based on tenant filtering rules
          print "  Updating available works... "
          allowed_types = TenantWorkTypeFilter.allowed_work_types
          Site.instance.update!(available_works: allowed_types)
          puts "✓"

          # Show what work types this tenant can see
          puts "  Available work types: #{allowed_types.join(', ')}"

        rescue => e
          errors += 1
          puts "  ✗ ERROR: #{e.message}"
          puts "    #{e.backtrace.first}"
        end
      end

      puts "\n" + "=" * 60
      puts "  SUMMARY"
      puts "=" * 60
      puts "  Total tenants: #{total_tenants}"
      puts "  Processed: #{processed}"
      puts "  Errors: #{errors}"
      puts "  Success: #{processed - errors}"
      puts "=" * 60
    end

    desc 'Reset metadata profiles and update available works for a specific tenant'
    task :reset_tenant, [:tenant] => :environment do |_t, args|
      tenant = args[:tenant]

      if tenant.blank?
        puts "\nError: Tenant must be specified"
        puts "Usage: rake hykuup:profiles:reset_tenant[tenant_cname]"
        exit 1
      end

      account = Account.find_by(tenant:) || Account.find_by(cname: tenant)

      if account.nil?
        puts "\nError: Tenant '#{tenant}' not found"
        exit 1
      end

      puts "\n" + "=" * 50
      puts "  RESETTING PROFILE FOR SINGLE TENANT"
      puts "=" * 50
      puts "  Tenant: #{account.cname}"
      puts "  Database: #{account.tenant}"
      puts "=" * 50
      puts "\n⚠️  WARNING: This will overwrite the existing metadata profile!"
      puts "   Any custom profile for this tenant will be lost and replaced."
      puts "   This action cannot be undone.\n"

      print "Are you sure you want to continue? Type 'yes' to confirm: "
      confirmation = STDIN.gets.chomp

      unless confirmation.casecmp('yes').zero?
        puts "\n❌ Operation cancelled by user."
        exit 0
      end

      puts "\n✅ Confirmed. Proceeding with profile reset...\n"

      begin
        # Switch to the tenant
        Apartment::Tenant.switch!(account.tenant)

        # Reset the metadata profile
        print "  Resetting profile... "
        Hyrax::FlexibleSchema.create_default_schema
        puts "✓"

        # Update available works based on tenant filtering rules
        print "  Updating available works... "
        allowed_types = TenantWorkTypeFilter.allowed_work_types
        Site.instance.update!(available_works: allowed_types)
        puts "✓"

        # Show what work types this tenant can see
        puts "\n  Available work types: #{allowed_types.join(', ')}"
        puts "=" * 50
        puts "  ✓ COMPLETED SUCCESSFULLY"
        puts "=" * 50

      rescue => e
        puts "\n  ✗ ERROR: #{e.message}"
        puts "  #{e.backtrace.first}"
        puts "=" * 50
        exit 1
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength
