# frozen_string_literal: true

# rubocop:disable Metrics/BlockLength
namespace :hykuup do
  namespace :mobius do
    desc 'Update Bulkrax field mappings across all Mobius tenants'
    task update_field_mappings: :environment do
      mobius_tenants = Account.where('cname LIKE ?', '%digitalmobius%').or(Account.where(cname: 'stephens.hykuup.com'))
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
      wcu_tenants = Account.where(cname: ['wcu.hykuup.com', 'unca.hykuup.com'])
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
end
# rubocop:enable Metrics/BlockLength
