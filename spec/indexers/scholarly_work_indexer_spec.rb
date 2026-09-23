# frozen_string_literal: true

# Generated via
#  `rails generate hyrax:work_resource ScholarlyWork`
require 'rails_helper'
require 'hyrax/specs/shared_specs/indexers'

RSpec.describe ScholarlyWorkIndexer do
  let(:indexer_class) { described_class }
  let!(:resource) do
    seed_flexible_schema_for('ScholarlyWork')
    Hyrax.persister.save(resource: ScholarlyWork.new)
  end

  it_behaves_like 'a Hyrax::Resource indexer'
end
