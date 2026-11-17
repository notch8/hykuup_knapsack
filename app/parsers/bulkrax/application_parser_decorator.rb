# frozen_string_literal: true

# OVERRIDE Bulkrax v10.0.1: CsvParser#real_zip_entries calls reject_unsafe_entry! on the
# parser instance, but 10.0.1 only defines it on the class, so every ZIP import fails as it
# starts. Remove once Bulkrax includes samvera/bulkrax#1188.
module Bulkrax
  module ApplicationParserDecorator
    def reject_unsafe_entry!(name)
      self.class.reject_unsafe_entry!(name)
    end
  end
end

Bulkrax::ApplicationParser.prepend(Bulkrax::ApplicationParserDecorator)
