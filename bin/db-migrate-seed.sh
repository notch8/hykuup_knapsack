#!/usr/bin/env ruby

require 'open3'
require 'bundler'
DIR = File.dirname(__FILE__)

def service_wait(address)
  run_command("#{DIR}/service-wait.sh #{address}")
end

def run_command(command)
  stdout, stderr, status = Open3.capture3(command)
  raise stderr unless status.success?
  puts stdout
  stdout
end

def migrations_list(query)
  result = run_command(query)
  result.split("\n").map(&:strip).reject(&:empty?)
rescue
  []
end

def create_database(db_host, db_user, db_password, db_name)
  check_query = "PGPASSWORD=#{db_password} psql -h #{db_host} -U #{db_user} postgres -t -c \"SELECT 1 FROM pg_database WHERE datname='#{db_name}'\""
  result = run_command(check_query).strip
  if result.empty?
    puts "Creating database #{db_name}"
    run_command("PGPASSWORD=#{db_password} psql -h #{db_host} -U #{db_user} postgres -c \"CREATE DATABASE \\\"#{db_name}\\\"\"")
  else
    puts "Database #{db_name} already exists"
  end
end

def bundled_migrations
  migration_list = Bundler.load.specs.inject([]) do |arr, spec|
    if File.exist?("#{spec.full_gem_path}/lib/*/engine.rb")
      migrations = Dir.glob("#{spec.full_gem_path}/db/migrate/*")
      migrations.each do |migration_path|
        arr.push(File.basename(migration_path).split('_').first)
      end
    end
    arr
  end
  Dir.glob('db/migrate/*.rb').each do |migration_path|
    migration_list.push(File.basename(migration_path).split('_').first)
  end
  migration_list
end

begin
  db_host = ENV['DB_HOST']
  db_port = ENV['DB_PORT']
  fcrepo_host = ENV['FCREPO_HOST']
  fcrepo_port = ENV['FCREPO_PORT']
  solr_host = ENV['SOLR_HOST']
  solr_port = ENV['SOLR_PORT']
  db_user = ENV['DB_USER']
  db_name = ENV['DB_NAME']
  db_password = ENV['DB_PASSWORD']

  service_wait("#{db_host}:#{db_port}")
  service_wait("#{fcrepo_host}:#{fcrepo_port}") if fcrepo_host
  service_wait("#{solr_host}:#{solr_port}")

  # Have to create DB prior to loading Rails because the Apartment initializer calls the DB before Rails is loaded enough to run `db:create`
  create_database(db_host, db_user, db_password, db_name)

  migrations_run_query = "PGPASSWORD=#{db_password} psql -h #{db_host} -U #{db_user} #{db_name} -t -c \"SELECT version FROM schema_migrations ORDER BY schema_migrations\""
  migrations_run = migrations_list(migrations_run_query)

  migrations_fs = bundled_migrations

  if (migrations_fs - migrations_run).size > 0
    run_command('bundle exec rails db:create')
    run_command('bundle exec rails db:migrate')
    run_command('bundle exec rails db:seed')
  end
rescue => e
  puts "An error occurred: #{e.message}"
  exit 1
end

puts 'all migrations have been run'
