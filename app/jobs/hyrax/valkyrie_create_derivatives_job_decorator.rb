# frozen_string_literal: true
# spec/hyku_knapsack/valkyrie_create_derivatives_job_spec.rb
require 'rails_helper'

RSpec.describe ValkyrieCreateDerivativesJob, type: :job do
  let(:malformed_pdf_path) { Rails.root.join("spec", "fixtures", "files", "malformed.pdf") }

  let(:file_id) { SecureRandom.uuid }
  let(:file_set_id) { SecureRandom.uuid }

  let(:file_metadata) do
    instance_double(
      "Hyrax::FileMetadata",
      file_identifier: file_id,
      video?: false
    )
  end

  before do
    allow(Hyrax.custom_queries).to receive(:find_file_metadata_by).with(id: file_id).and_return(file_metadata)
    allow(Hyrax.storage_adapter).to receive(:find_by).with(id: file_id).and_return(double(disk_path: malformed_pdf_path))
  end

  it "logs and reports derivative error to Sentry for malformed PDF" do
    if defined?(Sentry)
      expect(Sentry).to receive(:capture_exception).with(
        an_instance_of(StandardError),
        extra: hash_including(
          job: "ValkyrieCreateDerivativesJob",
          file_set_id:,
          file_id:
        )
      )
    end

    expect do
      described_class.new.perform(file_set_id, file_id)
    end.to raise_error(StandardError)
  end
end
