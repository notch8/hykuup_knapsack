# frozen_string_literal: true

module Bulkrax
  # OVERRIDE Bulkax v7.0.0:
  #   to add model to collections so CsvCollectionEntry objects are properly created
  #   to handle tar.gz files, MOBIUS has their data in tarballs intead of zips
  module CsvParserDecorator
    COMBINED_CSV_FILENAME = 'combined.csv'
    COMBINED_FILES_DIRNAME = 'files'

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    def untar(file_to_unzip)
      super

      # MOBIUS tarballs can be nested, as when you first extract,
      # it contains a single directory that then contains all the files
      # TODO: might be nice to contribute this back to Bulkrax
      directories = Dir.entries(importer_unzip_path).select do |entry|
        File.directory? File.join(importer_unzip_path, entry) and !['.', '..'].include?(entry)
      end

      # If there's only one directory, move its contents to the importer_unzip_path
      if directories.length == 1
        subdirectory_path = File.join(importer_unzip_path, directories.first)
        Dir.glob("#{subdirectory_path}/*").each do |file|
          FileUtils.mv(file, importer_unzip_path)
        end
      end

      coerce_unpacked_files!
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

    private

    def coerce_unpacked_files!
      combine_csvs
      combine_files
      local_coercion
      clean_up_upacked_files
    end

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    def combine_csvs
      return unless Dir.glob(File.join(importer_unzip_path, '*.csv')).length > 1

      combined_csv_path = File.join(importer_unzip_path, COMBINED_CSV_FILENAME)
      csv_file_paths = Dir.glob(File.join(importer_unzip_path, '*.csv'))

      # Collect all unique headers from all CSV files, starting with file and model since they do not originally exist
      all_headers = csv_file_paths.each_with_object(%w[file model identifier]) do |file_path, headers|
        CSV.foreach(file_path, headers: true) do |row|
          headers << row.headers
        end
      end.uniq.flatten

      # Open the combined CSV file for writing
      CSV.open(combined_csv_path, 'wb') do |combined_csv|
        combined_csv << all_headers

        csv_file_paths.each do |file_path|
          CSV.foreach(file_path, headers: true) do |row|
            combined_row = all_headers.index_with { |_header| nil }
            row.to_h.each { |key, value| combined_row[key] = value if combined_row.key?(key) }
            combined_csv << combined_row.values
          end
        end
      end
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

    # rubocop:disable Metrics/MethodLength
    def combine_files
      # return if there is only one directory and it is named 'files'
      return if Dir.glob(File.join(importer_unzip_path, '*')).length == 1 && Dir.exist?(File.join(importer_unzip_path, COMBINED_FILES_DIRNAME))

      file_paths = Dir.glob(File.join(importer_unzip_path, '*'))
      file_paths.select! { |file_path| Dir.exist?(file_path) }
      files = []
      file_paths.each do |file_path|
        files += Dir.glob(File.join(file_path, '*'))
      end

      combined_files_dir = File.join(importer_unzip_path, COMBINED_FILES_DIRNAME)
      Dir.mkdir(combined_files_dir) unless File.directory?(combined_files_dir)

      files.each do |file|
        FileUtils.mv(file, combined_files_dir)
      end
    end
    # rubocop:enable Metrics/MethodLength

    # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
    def local_coercion
      csv_path = File.join(importer_unzip_path, COMBINED_CSV_FILENAME)
      files = Dir.glob(File.join(importer_unzip_path, COMBINED_FILES_DIRNAME, '*'))
                 .map { |path| File.basename(path) }
                 .reject { |file| file.downcase.include?('thumbnail') }

      csv_rows = CSV.foreach(csv_path, headers: true, return_headers: true).map(&:to_hash)

      # Separate the header from the rest of the rows
      header = csv_rows.shift
      new_rows = csv_rows.each do |row|
        file_entry = files.select { |file| file.include?(row['ss_pid'].tr(':', '_')) }.join(',')

        # handle file column
        row['file'] = file_entry if file_entry.present?

        # handle model column
        row['model'] =
          if (row['bs_isCommunity'] || row['bs_isCollection'])&.downcase == 'true' || in_collection_and_community?(row)
            Hyrax.config.collection_model
          else
            'MobiusWork'
          end

        # handle identifier column
        row['identifier'] = row['ss_pid']
      end

      # Sort rows so that rows with 'model' equal to Hyrax.config.collection_model are at the top
      new_rows.sort_by! { |row| row['model'] == Hyrax.config.collection_model ? 0 : 1 }

      # Prepend the header back to the array
      new_rows.unshift(header)

      CSV.open(csv_path, 'wb') do |csv|
        new_rows.each do |row|
          # removing these columns because at this point we have the
          # model column and these don't make sense to keep anymore
          row.delete('bs_isCommunity')
          row.delete('bs_isCollection')
          row.delete('ss_pid')

          csv << row.values
        end
      end
    end
    # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

    def clean_up_upacked_files
      Dir.glob(File.join(importer_unzip_path, '*')).each do |file_path|
        next if File.basename(file_path) == COMBINED_CSV_FILENAME || File.basename(file_path) == COMBINED_FILES_DIRNAME

        FileUtils.rm_rf(file_path)
      end
    end

    # It has been noted that some of MOBIUS's CSVs don't indicate if it is a
    # bs_isCollection or bs_isCommunity, this is a final fallback as per client's
    # confirmation, all collections should be in a CSV that ends with 'C&C.csv'
    def in_collection_and_community?(row)
      csv_file_paths = Dir.glob(File.join(importer_unzip_path, '*C&C.csv'))
      CSV.foreach(csv_file_paths.first, headers: true) do |csv_row|
        return true if csv_row['ss_pid'] == row['ss_pid']
      end
    end
  end
end

Bulkrax::CsvParser.prepend(Bulkrax::CsvParserDecorator)
