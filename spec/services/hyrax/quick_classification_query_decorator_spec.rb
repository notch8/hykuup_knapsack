# frozen_string_literal: true

RSpec.describe Hyrax::QuickClassificationQuery, singletenant: true do
  describe "tenant-specific work type filtering for work creation" do
    let(:user) { create(:user) }

    before do
      # Ensure all work types are registered
      allow(Hyrax.config).to receive(:registered_curation_concern_types).and_return([
                                                                                      'GenericWork', 'Image', 'Etd', 'Oer', 'MobiusWork', 'ScholarlyWork'
                                                                                    ])

      # Mock user permissions to allow creation of all work types
      allow(user).to receive(:can?).with(:create, anything).and_return(true)
    end

    describe "tenant filtering" do
      context "for UNCA tenant" do
        before do
          site_instance = double('Site', available_works: ['GenericWork', 'Image', 'Etd', 'Oer', 'ScholarlyWork'])
          allow(Site).to receive(:instance).and_return(site_instance)
        end

        it "excludes MobiusWork from work creation options" do
          query = described_class.new(user)
          authorized_models = query.authorized_models

          expect(authorized_models.map(&:name)).to include('GenericWork', 'Image', 'Etd', 'Oer', 'ScholarlyWork')
          expect(authorized_models.map(&:name)).not_to include('MobiusWork')
        end
      end

      context "for Mobius tenant" do
        before do
          site_instance = double('Site', available_works: ['GenericWork', 'Image', 'Etd', 'Oer', 'MobiusWork'])
          allow(Site).to receive(:instance).and_return(site_instance)
        end

        it "excludes ScholarlyWork from work creation options" do
          query = described_class.new(user)
          authorized_models = query.authorized_models

          expect(authorized_models.map(&:name)).to include('GenericWork', 'Image', 'Etd', 'Oer', 'MobiusWork')
          expect(authorized_models.map(&:name)).not_to include('ScholarlyWork')
        end
      end

      context "for generic tenant" do
        before do
          site_instance = double('Site', available_works: ['GenericWork', 'Image', 'Etd', 'Oer'])
          allow(Site).to receive(:instance).and_return(site_instance)
        end

        it "excludes all tenant-specific work types from work creation options" do
          query = described_class.new(user)
          authorized_models = query.authorized_models

          expect(authorized_models.map(&:name)).to include('GenericWork', 'Image', 'Etd', 'Oer')
          expect(authorized_models.map(&:name)).not_to include('MobiusWork', 'ScholarlyWork')
        end
      end
    end
  end
end
