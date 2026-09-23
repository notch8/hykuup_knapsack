# frozen_string_literal: true

module Bulkrax
  module HasLocalProcessing
    # This method is called during build_metadata
    # add any special processing here, for example to reset a metadata property
    # to add a custom property from outside of the import data
    def add_local
      remove_escape_character_from_values!
      remove_duplicates_from_identifier!

      true
    end

    private

    def remove_escape_character_from_values!
      # ex. "Hello\\, there." => "Hello, there."
      parsed_metadata.each_value do |value|
        Array(value).each { |v| v.gsub!('\\,', ',') if v.is_a?(String) }
      end
    end

    def remove_duplicates_from_identifier!
      return if parsed_metadata['identifier'].blank?

      # ss_pid and sm_identifier both get parsed into identifier and they are both
      # the same, we only need one
      parsed_metadata['identifier'] = parsed_metadata['identifier'].uniq
    end
  end
end
