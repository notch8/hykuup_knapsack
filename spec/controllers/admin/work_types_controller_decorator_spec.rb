# frozen_string_literal: true

RSpec.describe Admin::WorkTypesController, singletenant: true do
  describe "tenant-specific work type filtering" do
    let(:admin_user) { create(:admin) }
    let(:controller_instance) { described_class.new }

    before do
      # Ensure all work types are registered
      allow(Hyrax.config).to receive(:registered_curation_concern_types).and_return([
                                                                                      'GenericWork', 'Image', 'Etd', 'Oer', 'MobiusWork', 'UncaWork', 'ScholarlyWork'
                                                                                    ])
    end
  end
end
