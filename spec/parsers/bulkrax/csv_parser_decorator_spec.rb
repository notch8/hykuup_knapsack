# frozen_string_literal: true
require 'rails_helper'

# rubocop:disable Metrics/BlockLength
RSpec.describe Bulkrax::CsvParserDecorator, type: :decorator do
  let(:csv_parser) { Bulkrax::CsvParser.new('double') }
  let(:file_to_unzip) { HykuKnapsack::Engine.root.join(File.join('spec', 'fixtures', 'test.tar.gz')).to_s }
  let(:importer_unzip_path) { HykuKnapsack::Engine.root.join('spec', 'fixtures', 'importer_unzip_path').to_s }

  before do
    clean_up
    allow(csv_parser).to receive(:importer_unzip_path).and_return(importer_unzip_path)
  end

  after { clean_up }

  describe '#unzip' do
    shared_examples 'unpacks tar.gz file' do
      it 'unpacks a tar.gz file' do
        expect(Dir.exist?(importer_unzip_path)).to be true
      end

      it 'creates the correct number of directories' do
        expect(Dir.glob(File.join(importer_unzip_path, '*')).count).to eq(2)
      end

      it 'creates the correct number of files' do
        expect(Dir.glob(File.join(importer_unzip_path, 'files', '*')).count).to eq(6)
      end
    end

    before do
      csv_parser.unzip(file_to_unzip)
    end

    it_behaves_like 'unpacks tar.gz file'

    # rubocop:disable RSpec/NestedGroups
    context 'when the tarball contains a single directory that then contains everything else' do
      let(:file_to_unzip) { HykuKnapsack::Engine.root.join(File.join('spec', 'fixtures', 'nested.tar.gz')).to_s }

      it_behaves_like 'unpacks tar.gz file'
    end
    # rubocop:enable RSpec/NestedGroups
  end

  describe 'the Combined CSV' do
    before do
      allow(csv_parser).to receive(:clean_up_upacked_files)
      csv_parser.unzip(file_to_unzip)
    end

    let(:combined_csv_path) { File.join(importer_unzip_path, Bulkrax::CsvParser::COMBINED_CSV_FILENAME) }
    let(:combined_csv_data) { CSV.read(combined_csv_path, headers: true).map(&:to_h) }
    let(:original_csv_paths) { Dir.glob(File.join(importer_unzip_path, '*.csv')) - [combined_csv_path] }
    let(:original_csv_data) do
      original_csv_paths.map { |csv_path| CSV.read(csv_path, headers: true).map(&:to_h) }.flatten
    end
    let(:original_headers) { original_csv_data.map(&:keys).flatten.uniq }
    let(:combined_headers) { combined_csv_data.first.keys }
    let(:added_headers) { %w[file model identifier] }
    let(:removed_headers) { %w[bs_isCommunity bs_isCollection ss_pid] }

    it 'has the correct headers' do
      expect(combined_headers).to match_array(original_headers - removed_headers + added_headers)
    end

    # rubocop:disable RSpec/ExampleLength
    it 'has all the data from the original CSVs into one' do
      original_csv_data.each do |original_row|
        original_row.except!(*removed_headers)

        matching_row = combined_csv_data.find do |combined_row|
          original_row.all? { |key, value| combined_row[key] == value }
        end

        expect(matching_row).not_to be_nil, "No matching row found for #{original_row}"
      end
    end
    # rubocop:enable RSpec/ExampleLength

    it 'has the collections at the top' do
      expected_collection_count = combined_csv_data.count { |row| row['model'] == Hyrax.config.collection_model }
      top_row_models = combined_csv_data.first(expected_collection_count).map { |row| row['model'] }
      expect(top_row_models).to all(eq(Hyrax.config.collection_model))
    end

    it 'has the MobiusWorks at the bottom' do
      expected_work_count = combined_csv_data.count { |row| row['model'] == 'MobiusWork' }
      bottom_row_models = combined_csv_data.last(expected_work_count).map { |row| row['model'] }
      expect(bottom_row_models).to all(eq('MobiusWork'))
    end

    it 'has files for each work' do
      # byebug
      expected_work_count = combined_csv_data.count { |row| row['model'] == 'MobiusWork' }
      bottom_row_files = combined_csv_data.last(expected_work_count).map { |row| row['file'] }
      expect(bottom_row_files).to include('vital_7693+SOURCE1+SOURCE1.0.pdf,vital_7693+SOURCE1+SOURCE1.1.pdf',
                                      'vital_16141+SOURCE1+SOURCE1.0.jpeg', 'vital_16140+SOURCE1+SOURCE1.0.jpeg',
                                      'vital_7507+SOURCE1+SOURCE1.0.tiff')
    end

    it 'has the correct identifiers' do
      # byebug
      identifiers = combined_csv_data.map { |row| row['identifier'] }
      expect(identifiers).to include('vital:5891', 'vital:16160', 'vital:7693', 'vital:16141', 'vital:16140', 'vital:7507')
    end

    after { csv_parser.send(:clean_up_upacked_files) }
  end

  def clean_up
    FileUtils.rm_rf(importer_unzip_path) if Dir.exist?(importer_unzip_path)
  end
end
# rubocop:enable Metrics/BlockLength
