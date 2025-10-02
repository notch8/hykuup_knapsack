# frozen_string_literal: true

# rubocop:disable Metrics/BlockLength

# ==============================================================================
#  Helpers for colored CLI output
# ==============================================================================
def red(text); "\e[31m#{text}\e[0m"; end
def green(text); "\e[32m#{text}\e[0m"; end
def yellow(text); "\e[33m#{text}\e[0m"; end
def blue(text); "\e[34m#{text}\e[0m"; end
def magenta(text); "\e[35m#{text}\e[0m"; end
def cyan(text); "\e[36m#{text}\e[0m"; end
def bold(text); "\e[1m#{text}\e[0m"; end
def underline(text); "\e[4m#{text}\e[0m"; end
def bg_red(text); "\e[41m#{text}\e[0m"; end
def bg_green(text); "\e[42m#{text}\e[0m"; end
def bg_yellow(text); "\e[43m#{text}\e[0m"; end

# Enhanced visual separators
def separator(char = '=', length = 80); char * length; end
def thick_separator; "=" * 80; end
def thin_separator; "─" * 80; end

# Status indicators
def success_icon; green("✓"); end
def error_icon; red("✗"); end
def warning_icon; yellow("⚠"); end
def info_icon; blue("ℹ"); end
def arrow_icon; cyan("→"); end

namespace :hykuup do
  namespace :mobius do
    desc 'Update Bulkrax field mappings across all Mobius tenants'
    task update_field_mappings: :environment do
      mobius_tenants = Account.where(part_of_consortia: 'mobius')
                              .or(Account.where('cname LIKE ?', '%mobius%'))
                              .or(Account.where(cname: 'stephens.hykuup.com'))
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
      wcu_tenants = Account.where(part_of_consortia: 'unca')
                           .or(Account.where('cname LIKE ?', '%unca%'))
                           .or(Account.where(cname: 'wcu.hykuup.com'))
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
    desc 'Add tenant-specific metadata profiles (preserves existing profiles)'
    task add_tenant_profiles: :environment do
      puts "\n#{thick_separator}"
      puts bold(cyan("  🚀 ADDING TENANT-SPECIFIC METADATA PROFILES"))
      puts thick_separator
      puts "\n#{green('✅ This will ADD new profiles without destroying existing ones.')}"
      puts "   Existing profiles will be preserved for historical reference.\n"

      total_tenants = Account.count
      processed = 0
      errors = 0
      skipped = 0
      success = 0
      failed_tenants = [] # Track which tenants failed
      skipped_tenants = [] # Track which tenants were skipped

      Account.find_each do |account|
        processed += 1
        puts "\n#{thin_separator}"
        puts "#{arrow_icon} [#{processed}/#{total_tenants}] #{bold(account.cname)}"
        puts "   #{info_icon} Tenant: #{account.tenant}"
        puts "   #{info_icon} Consortium: #{account.part_of_consortia || 'None'}"

        begin
          # Switch to the tenant
          Apartment::Tenant.switch!(account.tenant)

          # Add the tenant-specific profile (preserves existing)
          print "   #{info_icon} Validating and adding tenant-specific profile... "
          result = create_validated_profile

          if result[:success]
            puts success_icon
            success += 1

            if result[:warnings].any?
              puts "   #{warning_icon}  Warnings:"
              result[:warnings].each { |w| puts "      #{yellow('•')} #{w}" }
            end
          else
            puts error_icon + " " + red("SKIPPED")
            skipped += 1
            skipped_tenants << { tenant: account.cname, reason: result[:error] }
            puts "   #{error_icon} Reason: #{red(result[:error])}"
            next
          end

          # Update available works based on tenant filtering rules
          print "   #{info_icon} Updating available works... "
          allowed_types = TenantWorkTypeFilter.allowed_work_types
          Site.instance.update!(available_works: allowed_types)
          puts success_icon

          # Show what work types this tenant can see
          puts "   #{success_icon} Available work types: #{green(allowed_types.join(', '))}"

        rescue StandardError => e
          # Only rescue StandardError to avoid masking system-level exceptions.
          errors += 1
          failed_tenants << { tenant: account.cname, reason: e.message, error: e }
          puts "   #{error_icon} #{red('ERROR')}: #{e.message}"
          puts "      #{red('↳')} #{e.backtrace.first}"
        end
      end

      puts "\n#{thick_separator}"
      puts bold(cyan("  📊 SUMMARY"))
      puts thick_separator
      
      # Summary statistics with color coding
      puts "\n#{info_icon} #{bold('Statistics:')}"
      puts "   Total tenants: #{bold(total_tenants)}"
      puts "   Processed: #{bold(processed)}"
      puts "   #{success_icon} Successfully updated: #{green(bold(success))}"
      puts "   #{warning_icon} Skipped (validation failed): #{yellow(bold(skipped))}"
      puts "   #{error_icon} Errors: #{red(bold(errors))}"

      # Show failures prominently
      if failed_tenants.any?
        puts "\n#{bg_red('  ❌ FAILED TENANTS  ')}"
        puts red(thin_separator)
        failed_tenants.each_with_index do |item, index|
          puts "\n#{red("#{index + 1}.")} #{bold(item[:tenant])}"
          puts "   #{error_icon} Error: #{red(item[:reason])}"
        end
        puts red(thin_separator)
      end

      # Show skipped tenants
      if skipped_tenants.any?
        puts "\n#{bg_yellow('  ⚠️  SKIPPED TENANTS  ')}"
        puts yellow(thin_separator)
        skipped_tenants.each_with_index do |item, index|
          puts "\n#{yellow("#{index + 1}.")} #{bold(item[:tenant])}"
          puts "   #{warning_icon} Reason: #{yellow(item[:reason])}"
        end
        puts yellow(thin_separator)
      end

      # Final status
      if errors > 0 || skipped > 0
        puts "\n#{red('❌ Some tenants had issues. See details above.')}"
      else
        puts "\n#{green('✅ All tenants processed successfully!')}"
      end
      
      puts thick_separator
    end

    desc 'Add tenant-specific metadata profiles for specific consortium (preserves existing profiles)'
    task :add_consortium_profiles, [:consortium] => :environment do |_t, args|
      consortium = args[:consortium]

      if consortium.blank?
        puts red("\nError: Consortium must be specified")
        puts "Usage: rake hykuup:profiles:add_consortium_profiles[consortium_identifier]"
        puts "Available consortia: #{Consortium.identifiers.join(', ')}"
        exit 1
      end

      unless Consortium.identifiers.include?(consortium)
        puts red("\nError: Invalid consortium '#{consortium}'")
        puts "Available consortia: #{Consortium.identifiers.join(', ')}"
        exit 1
      end

      puts "\n#{thick_separator}"
      puts bold(cyan("  🏢 ADDING PROFILES FOR #{consortium.upcase} CONSORTIUM"))
      puts thick_separator
      puts "\n#{green('✅ This will ADD new profiles without destroying existing ones.')}"
      puts "   Existing profiles will be preserved for historical reference.\n"

      consortium_tenants = Account.where(part_of_consortia: consortium)
      total_tenants = consortium_tenants.count
      processed = 0
      errors = 0
      success = 0
      failed_tenants = [] # Track which tenants failed
      skipped_tenants = [] # Track which tenants were skipped

      if total_tenants.zero?
        puts yellow("No tenants found for consortium '#{consortium}'")
        exit 0
      end

      consortium_tenants.find_each do |account|
        processed += 1
        puts "\n#{thin_separator}"
        puts "#{arrow_icon} [#{processed}/#{total_tenants}] #{bold(account.cname)}"
        puts "   #{info_icon} Tenant: #{account.tenant}"
        puts "   #{info_icon} Consortium: #{account.part_of_consortia}"

        begin
          # Switch to the tenant
          Apartment::Tenant.switch!(account.tenant)

          # Add the tenant-specific profile (preserves existing)
          print "   #{info_icon} Validating and adding tenant-specific profile... "
          result = create_validated_profile

          if result[:success]
            puts success_icon
            success += 1

            if result[:warnings].any?
              puts "   #{warning_icon}  Warnings:"
              result[:warnings].each { |w| puts "      #{yellow('•')} #{w}" }
            end
          else
            puts error_icon + " " + red("SKIPPED")
            errors += 1
            skipped_tenants << { tenant: account.cname, reason: result[:error] }
            puts "   #{error_icon} Reason: #{red(result[:error])}"
            next
          end
        rescue StandardError => e
          puts error_icon + " " + red("FAILED")
          errors += 1
          failed_tenants << { tenant: account.cname, reason: e.message, error: e }
          puts "   #{error_icon} #{red('ERROR')}: #{e.message}"
          puts "      #{red('↳')} #{e.backtrace.first}"
        end
      end

      puts "\n#{thick_separator}"
      puts bold(cyan("  📊 SUMMARY"))
      puts thick_separator
      
      # Summary statistics with color coding
      puts "\n#{info_icon} #{bold('Statistics:')}"
      puts "   Consortium: #{bold(consortium)}"
      puts "   Total tenants: #{bold(total_tenants)}"
      puts "   Processed: #{bold(processed)}"
      puts "   #{success_icon} Successfully updated: #{green(bold(success))}"
      puts "   #{warning_icon} Skipped (validation failed): #{yellow(bold(skipped_tenants.count))}"
      puts "   #{error_icon} Errors: #{red(bold(failed_tenants.count))}"

      # Show failures prominently
      if failed_tenants.any?
        puts "\n#{bg_red('  ❌ FAILED TENANTS  ')}"
        puts red(thin_separator)
        failed_tenants.each_with_index do |item, index|
          puts "\n#{red("#{index + 1}.")} #{bold(item[:tenant])}"
          puts "   #{error_icon} Error: #{red(item[:reason])}"
        end
        puts red(thin_separator)
      end

      # Show skipped tenants
      if skipped_tenants.any?
        puts "\n#{bg_yellow('  ⚠️  SKIPPED TENANTS  ')}"
        puts yellow(thin_separator)
        skipped_tenants.each_with_index do |item, index|
          puts "\n#{yellow("#{index + 1}.")} #{bold(item[:tenant])}"
          puts "   #{warning_icon} Reason: #{yellow(item[:reason])}"
        end
        puts yellow(thin_separator)
      end

      # Final status
      if failed_tenants.any? || skipped_tenants.any?
        puts "\n#{red('❌ Some tenants had issues. See details above.')}"
      else
        puts "\n#{green('✅ All tenants processed successfully!')}"
      end
      
      puts thick_separator
    end

    desc 'Add tenant-specific metadata profile for a specific tenant (preserves existing profiles)'
    task :add_tenant_profile, [:tenant] => :environment do |_t, args|
      tenant = args[:tenant]

      if tenant.blank?
        puts red("\nError: Tenant must be specified")
        puts "Usage: rake hykuup:profiles:add_tenant_profile[tenant_cname_or_name]"
        exit 1
      end

      # Find the account by its tenant UUID, cname, or internal name
      account = Account.find_by(tenant: tenant) || Account.find_by(cname: tenant) || Account.find_by(name: tenant)

      if account.nil?
        puts red("\nError: Tenant '#{tenant}' not found by tenant UUID, cname, or name")
        exit 1
      end

      puts "\n#{thick_separator}"
      puts bold(cyan("  🎯 ADDING TENANT-SPECIFIC PROFILE FOR SINGLE TENANT"))
      puts thick_separator
      puts "\n#{info_icon} #{bold('Tenant Details:')}"
      puts "   Tenant: #{bold(account.cname)}"
      puts "   Database: #{account.tenant}"
      puts "   Consortium: #{account.part_of_consortia || 'None'}"
      puts "\n#{green('✅ This will ADD a new profile without destroying existing ones.')}"
      puts "   Existing profiles will be preserved for historical reference.\n"

      begin
        # Switch to the tenant
        Apartment::Tenant.switch!(account.tenant)

        # Add the tenant-specific profile (preserves existing)
        print "#{info_icon} Validating and adding tenant-specific profile... "
        result = create_validated_profile

        if result[:success]
          puts success_icon

          if result[:warnings].any?
            puts "\n#{warning_icon}  Warnings:"
            result[:warnings].each { |w| puts "   #{yellow('•')} #{w}" }
          end
        else
          puts error_icon + " " + red("FAILED")
          puts "\n#{red('❌ Validation Error:')} #{result[:error]}"
          puts "\nThe profile could not be created because it would be incompatible"
          puts "with the existing data or tenant configuration."
          puts thick_separator
          exit 1
        end

        # Update available works based on tenant filtering rules
        print "#{info_icon} Updating available works... "
        allowed_types = TenantWorkTypeFilter.allowed_work_types
        Site.instance.update!(available_works: allowed_types)
        puts success_icon

        # Show what work types this tenant can see
        puts "\n#{success_icon} Available work types: #{green(allowed_types.join(', '))}"
        puts thick_separator
        puts green("✅ COMPLETED SUCCESSFULLY")
        puts thick_separator

      rescue StandardError => e
        # Only rescue StandardError to avoid masking system-level exceptions.
        puts error_icon + " " + red("ERROR")
        puts "\n#{red('❌ Error:')} #{e.message}"
        puts "   #{red('↳')} #{e.backtrace.first}"
        puts thick_separator
        exit 1
      end
    end

    desc 'Reset metadata profiles and update available works for all tenants (DESTRUCTIVE)'
    task reset_all: :environment do
      puts "\n#{thick_separator}"
      puts bold(red("  ⚠️  RESETTING PROFILES AND AVAILABLE WORKS FOR ALL TENANTS"))
      puts thick_separator
      puts "\n#{bg_yellow('  ⚠️  WARNING: This will overwrite ALL existing metadata profiles!  ')}"
      puts "   Custom profiles will be lost and replaced with tenant-specific defaults."
      puts "   This action cannot be undone.\n"
      puts "   Consider using 'rake hykuup:profiles:add_tenant_profiles' instead.\n"

      print "Are you sure you want to continue? Type 'yes' to confirm: "
      confirmation = STDIN.gets.chomp

      unless confirmation.casecmp('yes').zero?
        puts red("\n❌ Operation cancelled by user.")
        exit 0
      end

      puts green("\n✅ Confirmed. Proceeding with profile reset...\n")

      total_tenants = Account.count
      processed = 0
      errors = 0
      success = 0
      failed_tenants = [] # Track which tenants failed
      skipped_tenants = [] # Track which tenants were skipped

      Account.find_each do |account|
        processed += 1
        puts "\n#{thin_separator}"
        puts "#{arrow_icon} [#{processed}/#{total_tenants}] #{bold(account.cname)}"
        puts "   #{info_icon} Tenant: #{account.tenant}"
        puts "   #{info_icon} Consortium: #{account.part_of_consortia || 'None'}"

        begin
          # Switch to the tenant
          Apartment::Tenant.switch!(account.tenant)

          # VALIDATE FIRST before destroying anything!
          print "   #{info_icon} Validating new profile... "
          result = load_and_validate_profile

          unless result[:success]
            puts error_icon + " " + red("FAILED")
            puts "\n   #{red('❌ Validation Error:')} #{result[:error]}"
            puts "\n   The new profile is invalid. Existing profile has NOT been deleted."
            puts "   Your tenant still has its current profile."
            puts red(thin_separator)
            skipped_tenants << { tenant: account.cname, reason: result[:error] }
            next
          end
          puts success_icon
          profile_data = result[:data]

          # Reset the metadata profile (only after validation passes!)
          print "   #{info_icon} Deleting old profile and creating new one... "
          Hyrax::FlexibleSchema.destroy_all
          Hyrax::FlexibleSchema.create!(profile: profile_data)
          puts success_icon

          # Update available works based on tenant filtering rules
          print "   #{info_icon} Updating available works... "
          allowed_types = TenantWorkTypeFilter.allowed_work_types
          Site.instance.update!(available_works: allowed_types)
          puts success_icon

          # Show what work types this tenant can see
          puts "   #{success_icon} Available work types: #{green(allowed_types.join(', '))}"
          success += 1

        rescue StandardError => e
          # Only rescue StandardError to avoid masking system-level exceptions.
          errors += 1
          failed_tenants << { tenant: account.cname, reason: e.message, error: e }
          puts "   #{error_icon} #{red('ERROR')}: #{e.message}"
          puts "      #{red('↳')} #{e.backtrace.first}"
        end
      end

      puts "\n#{thick_separator}"
      puts bold(cyan("  📊 SUMMARY"))
      puts thick_separator
      
      # Summary statistics with color coding
      puts "\n#{info_icon} #{bold('Statistics:')}"
      puts "   Total tenants: #{bold(total_tenants)}"
      puts "   Processed: #{bold(processed)}"
      puts "   #{success_icon} Successfully reset: #{green(bold(success))}"
      puts "   #{warning_icon} Skipped (validation failed): #{yellow(bold(skipped_tenants.count))}"
      puts "   #{error_icon} Errors: #{red(bold(failed_tenants.count))}"

      # Show failures prominently
      if failed_tenants.any?
        puts "\n#{bg_red('  ❌ FAILED TENANTS  ')}"
        puts red(thin_separator)
        failed_tenants.each_with_index do |item, index|
          puts "\n#{red("#{index + 1}.")} #{bold(item[:tenant])}"
          puts "   #{error_icon} Error: #{red(item[:reason])}"
        end
        puts red(thin_separator)
      end

      # Show skipped tenants
      if skipped_tenants.any?
        puts "\n#{bg_yellow('  ⚠️  SKIPPED TENANTS  ')}"
        puts yellow(thin_separator)
        skipped_tenants.each_with_index do |item, index|
          puts "\n#{yellow("#{index + 1}.")} #{bold(item[:tenant])}"
          puts "   #{warning_icon} Reason: #{yellow(item[:reason])}"
        end
        puts yellow(thin_separator)
      end

      # Final status
      if failed_tenants.any? || skipped_tenants.any?
        puts "\n#{red('❌ Some tenants had issues. See details above.')}"
      else
        puts "\n#{green('✅ All tenants processed successfully!')}"
      end
      
      puts thick_separator
    end

    desc 'Reset metadata profiles and update available works for a specific tenant (DESTRUCTIVE)'
    task :reset_tenant, [:tenant] => :environment do |_t, args|
      tenant = args[:tenant]

      if tenant.blank?
        puts red("\nError: Tenant must be specified")
        puts "Usage: rake hykuup:profiles:reset_tenant[tenant_cname_or_name]"
        exit 1
      end

      # Find the account by its tenant UUID, cname, or internal name
      account = Account.find_by(tenant: tenant) || Account.find_by(cname: tenant) || Account.find_by(name: tenant)

      if account.nil?
        puts red("\nError: Tenant '#{tenant}' not found by tenant UUID, cname, or name")
        exit 1
      end

      puts "\n#{thick_separator}"
      puts bold(red("  ⚠️  RESETTING PROFILE FOR SINGLE TENANT"))
      puts thick_separator
      puts "\n#{info_icon} #{bold('Tenant Details:')}"
      puts "   Tenant: #{bold(account.cname)}"
      puts "   Database: #{account.tenant}"
      puts "   Consortium: #{account.part_of_consortia || 'None'}"
      puts "\n#{bg_yellow('  ⚠️  WARNING: This will overwrite the existing metadata profile!  ')}"
      puts "   Any custom profile for this tenant will be lost and replaced."
      puts "   This action cannot be undone.\n"
      puts "   Consider using 'rake hykuup:profiles:add_tenant_profile[#{tenant}]' instead.\n"

      print "Are you sure you want to continue? Type 'yes' to confirm: "
      confirmation = STDIN.gets.chomp

      unless confirmation.casecmp('yes').zero?
        puts red("\n❌ Operation cancelled by user.")
        exit 0
      end

      puts green("\n✅ Confirmed. Proceeding with profile reset...\n")

      begin
        # Switch to the tenant
        Apartment::Tenant.switch!(account.tenant)

        # VALIDATE FIRST before destroying anything!
        print "#{info_icon} Validating new profile... "
        result = load_and_validate_profile

        unless result[:success]
          puts error_icon + " " + red("FAILED")
          error_message = result[:error]
          puts "\n#{red('❌ Validation Error:')} #{error_message}"
          puts "\nThe new profile is invalid. Existing profile has NOT been deleted."
          puts "Your tenant still has its current profile."
          puts thick_separator
          exit 1
        end
        puts success_icon
        profile_data = result[:data]

        # Reset the metadata profile (only after validation passes!)
        print "#{info_icon} Deleting old profile and creating new one... "
        Hyrax::FlexibleSchema.destroy_all
        Hyrax::FlexibleSchema.create!(profile: profile_data)
        puts success_icon

        # Update available works based on tenant filtering rules
        print "#{info_icon} Updating available works... "
        allowed_types = TenantWorkTypeFilter.allowed_work_types
        Site.instance.update!(available_works: allowed_types)
        puts success_icon

        # Show what work types this tenant can see
        puts "\n#{success_icon} Available work types: #{green(allowed_types.join(', '))}"
        puts thick_separator
        puts green("✅ COMPLETED SUCCESSFULLY")
        puts thick_separator

      rescue StandardError => e
        # Only rescue StandardError to avoid masking system-level exceptions.
        puts error_icon + " " + red("ERROR")
        puts "\n#{red('❌ Error:')} #{e.message}"
        puts "   #{red('↳')} #{e.backtrace.first}"
        puts thick_separator
        exit 1
      end
    end
  end

  # Helper method to create a profile with validation
  # @return [Hash] { success: Boolean, error: String, warnings: Array<String> }
  def create_validated_profile
    warnings = []
    profile_data = load_and_validate_profile

    return profile_data if profile_data[:success] == false

    # Check for existing works that might become orphaned
    existing_work_warnings = check_existing_work_types(profile_data[:data])
    warnings.concat(existing_work_warnings) if existing_work_warnings.any?

    # Create the profile
    Hyrax::FlexibleSchema.create!(profile: profile_data[:data])
    { success: true, error: nil, warnings: warnings }
  rescue StandardError => e
    error_message = enhance_error_message_for_cli(e.message)
    { success: false, error: error_message, warnings: [] }
  end

  # Load and validate profile data
  # @return [Hash] Profile data or error result
  def load_and_validate_profile
    m3_profile_path = Hyrax::FlexibleSchema.tenant_specific_profile_path
    profile_data = YAML.safe_load_file(m3_profile_path)

    validate_tenant_work_types!(profile_data)
    # Use the service directly for a more comprehensive validation check
    validator = Hyrax::FlexibleSchemaValidatorService.new(profile: profile_data)
    validator.validate!

    if validator.errors.any?
      error_message = enhance_error_message_for_cli(validator.errors.first)
      return { success: false, error: error_message, warnings: [] }
    end

    { success: true, data: profile_data }
  rescue StandardError => e
    error_message = enhance_error_message_for_cli(e.message)
    { success: false, error: error_message, warnings: [] }
  end

  # Enhance error messages for CLI with helpful migration instructions
  # @param error [String] The original error message
  # @return [String] Enhanced error message with CLI-specific guidance
  def enhance_error_message_for_cli(error)
    # Check if this is an "existing records" error
    if error =~ /Classes with existing records cannot be removed from the profile: (.+)\./
      work_types = Regexp.last_match(1).split(', ').map { |wt| wt.gsub(/Resource$/, '') }.uniq
      first_type = work_types.first

      enhanced = "#{error}\n\n"
      enhanced += yellow("  💡 To fix this issue:\n")
      enhanced += "  1. Migrate the existing works to an allowed work type:\n"
      enhanced += "     rake hykuup:migrate_work_class[#{first_type},GenericWork,#{current_tenant_name}]\n"
      enhanced += "  2. Then run this profile update task again\n"

      enhanced += "\n  Note: You have multiple work types to migrate: #{work_types.join(', ')}" if work_types.length > 1

      return enhanced
    end

    # Return original error if not an existing records error
    error
  end

  # Get the current tenant name for helpful error messages
  # @return [String] The current tenant's cname or a generic placeholder
  def current_tenant_name
    account = Account.find_by(tenant: Apartment::Tenant.current)
    account&.cname || 'tenant_name'
  end

  # Validates that the profile doesn't contain work types restricted for the current tenant
  # @param profile_data [Hash] The parsed YAML profile data
  # @raise [StandardError] if profile contains work types not allowed for the current tenant
  def validate_tenant_work_types!(profile_data)
    return unless profile_data&.dig('classes')

    profile_work_types = extract_profile_work_types(profile_data)
    excluded_work_types = TenantWorkTypeFilter.excluded_work_types

    forbidden_work_types = profile_work_types & excluded_work_types

    return unless forbidden_work_types.any?

    account = Account.find_by(tenant: Apartment::Tenant.current)
    tenant_name = account&.cname || 'this tenant'
    allowed_work_types = TenantWorkTypeFilter.allowed_work_types

    raise StandardError,
          "This profile contains work types (#{forbidden_work_types.join(', ')}) that are not allowed for #{tenant_name}. " \
          "Please use a profile that only contains work types appropriate for your tenant. " \
          "Allowed work types for #{tenant_name}: #{allowed_work_types.join(', ')}."
  end

  # Extract work type names from the profile data
  # @param profile_data [Hash] The parsed YAML profile data
  # @return [Array<String>] Array of work type names found in the profile
  def extract_profile_work_types(profile_data)
    profile_classes = profile_data.dig('classes')&.keys || []
    profile_classes.map { |klass| klass.gsub(/Resource$/, '') }
  end

  # Check if there are existing works that aren't in the new profile
  # @param profile_data [Hash] The parsed YAML profile data
  # @return [Array<String>] Array of warning messages
  def check_existing_work_types(profile_data)
    warnings = []
    profile_work_types = extract_profile_work_types(profile_data).map { |t| "#{t}Resource" }

    Hyrax.config.registered_curation_concern_types.each do |work_type|
      warning = check_work_type_for_existing_records(work_type, profile_work_types)
      warnings << warning if warning
    end

    warnings
  end

  # Check a specific work type for existing records
  # @param work_type [String] The work type to check
  # @param profile_work_types [Array<String>] Work types in the new profile
  # @return [String, nil] Warning message if records exist, nil otherwise
  def check_work_type_for_existing_records(work_type, profile_work_types)
    work_type_resource = "#{work_type}Resource"
    return nil if profile_work_types.include?(work_type_resource)

    model_class = work_type_resource.constantize
    count = Hyrax.query_service.count_all_of_model(model: model_class)
    return "Found #{count} existing #{work_type} record(s) that won't be in the new profile" if count.positive?

    nil
  rescue NameError
    nil # Work type not defined, skip
  rescue StandardError => e
    Rails.logger.warn "Could not check for existing #{work_type} records: #{e.message}"
    nil
  end
end
# rubocop:enable Metrics/BlockLength
