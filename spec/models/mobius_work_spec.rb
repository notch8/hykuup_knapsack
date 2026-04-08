# frozen_string_literal: true

# Generated via
#  `rails generate hyrax:work_resource MobiusWork`
require 'rails_helper'

RSpec.describe MobiusWork do
  subject(:work) { described_class.new }

  # In flexible metadata mode (HYRAX_FLEXIBLE=true), attributes are provided
  # by the tenant's M3 profile rather than static schema includes.
  # The 'a Hyrax::Work' shared spec requires static schema attributes.
  # it_behaves_like 'a Hyrax::Work'

  it { is_expected.to be_a(Hyrax::Work) }
  it { expect(described_class.ancestors).to include(Hyrax::NestedWorks) }
end
