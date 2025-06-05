# frozen_string_literal: true
require 'rails_helper'

RSpec.describe ValkyrieCreateDerivativesJob, type: :job do
  let(:file_set_id) { SecureRandom.uuid }
  let(:file_id) { SecureRandom.uuid }

  let(:file_metadata) do
    instance_double(
      "Hyrax::FileMetadata",
      file_identifier: file_id,
      video?: false,
      audio?: false
    )
  end

  before do
    allow(Hyrax.custom_queries).to receive(:find_file_metadata_by).with(id: file_id).and_return(file_metadata)
    allow(Hyrax.storage_adapter).to receive(:find_by).with(id: file_id).and_return(double(disk_path: "/dev/null"))
  end

  it 'logs and reports an error to Sentry if derivative generation fails' do
    error = StandardError.new("derivative failed")
    # allow(Hyrax::DerivativeService).to receive(:for).and_return(double(create_derivatives: raise(error)))
    fake_derivative_service = double
    allow(Hyrax::DerivativeService).to receive(:for).and_return(fake_derivative_service)
    allow(fake_derivative_service).to receive(:create_derivatives).and_raise(error)

    if defined?(Sentry)
      expect(Sentry).to receive(:capture_exception).with(
        error,
        extra: hash_including(
          job: "ValkyrieCreateDerivativesJob",
          file_set_id:,
          file_id:
        )
      )
    end

    expect do
      described_class.new.perform(file_set_id, file_id)
    end.to raise_error(StandardError, "derivative failed")
  end
end
