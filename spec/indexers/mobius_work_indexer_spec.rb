# frozen_string_literal: true

# Generated via
#  `rails generate hyrax:work_resource MobiusWork`
require 'rails_helper'

RSpec.describe MobiusWorkIndexer do
  subject(:indexer) { described_class.new(resource: MobiusWork.new) }

  # In flexible metadata mode, attributes come from the tenant's M3 profile.
  # The 'a Hyrax::Resource indexer' shared spec requires static depositor attribute.
  # it_behaves_like 'a Hyrax::Resource indexer'

  it { is_expected.to be_a(Hyrax::ValkyrieWorkIndexer) }
  it { expect(described_class.ancestors).to include(HykuIndexing) }
end
