# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Bulkrax::ApplicationParserDecorator, type: :decorator do
  let(:parser) { Bulkrax::CsvParser.new('double') }

  it 'accepts a safe ZIP entry name' do
    expect { parser.reject_unsafe_entry!('files/photo-01.jpg') }.not_to raise_error
  end

  it 'rejects an entry that escapes the import directory' do
    expect { parser.reject_unsafe_entry!('../../etc/passwd') }.to raise_error(Bulkrax::UnzipError, /unsafe path/)
  end
end
