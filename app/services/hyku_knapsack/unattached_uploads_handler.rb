# frozen_string_literal: true

# OVERRIDE Hyrax v5.3.0 Hyrax::WorkUploadsHandler#attach and #append_to_work to
# create file sets without adding them to the work: no lock, no work save, no
# events and no ingest. Bulkrax's relationship pass attaches each file set and
# then queues its ingest.
module HykuKnapsack
  class UnattachedUploadsHandler < Hyrax::WorkUploadsHandler
    # @return [Array<Hash>] a { file_set:, user:, job: } payload per file set created
    def attach
      Array.wrap(files).each_with_index.map do |file, index|
        make_file_set_and_ingest(file, file_set_params[index] || {})
      end
    end

    private

    def append_to_work(_file_set); end
  end
end
