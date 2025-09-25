# frozen_string_literal: true

RSpec.describe Hyrax::QuickClassificationQuery, singletenant: true do
  describe "tenant-specific work type filtering for work creation" do
    let(:user) { create(:user) }

    before do
      # Ensure all work types are registered
      allow(Hyrax.config).to receive(:registered_curation_concern_types).and_return([
                                                                                      'GenericWork', 'Image', 'Etd', 'Oer', 'MobiusWork', 'UncaWork', 'ScholarlyWork'
                                                                                    ])

      # Mock user permissions to allow creation of all work types
      allow(user).to receive(:can?).with(:create, anything).and_return(true)
    end

    describe "tenant filtering" do
      context "for UNCA tenant" do
        before do
          allow(Apartment::Tenant).to receive(:current).and_return('unca')
          account = double('Account', cname: 'unca.hykuup.com')
          allow(Account).to receive(:find_by).with(tenant: 'unca').and_return(account)
        end

        it "excludes MobiusWork and UncaWork from work creation options" do
          query = described_class.new(user)
          authorized_models = query.authorized_models

          expect(authorized_models.map(&:name)).to include('GenericWork', 'Image', 'Etd', 'Oer', 'ScholarlyWork')
          expect(authorized_models.map(&:name)).not_to include('MobiusWork', 'UncaWork')
        end
      end

      context "for Mobius tenant" do
        before do
          allow(Apartment::Tenant).to receive(:current).and_return('mobius')
          account = double('Account', cname: 'example.digitalmobius.org')
          allow(Account).to receive(:find_by).with(tenant: 'mobius').and_return(account)
        end

        it "excludes UncaWork and ScholarlyWork from work creation options" do
          query = described_class.new(user)
          authorized_models = query.authorized_models

          expect(authorized_models.map(&:name)).to include('GenericWork', 'Image', 'Etd', 'Oer', 'MobiusWork')
          expect(authorized_models.map(&:name)).not_to include('UncaWork', 'ScholarlyWork')
        end
      end

      context "for generic tenant" do
        before do
          allow(Apartment::Tenant).to receive(:current).and_return('generic')
          account = double('Account', cname: 'example.com')
          allow(Account).to receive(:find_by).with(tenant: 'generic').and_return(account)
        end

        it "excludes all tenant-specific work types from work creation options" do
          query = described_class.new(user)
          authorized_models = query.authorized_models

          expect(authorized_models.map(&:name)).to include('GenericWork', 'Image', 'Etd', 'Oer')
          expect(authorized_models.map(&:name)).not_to include('MobiusWork', 'UncaWork', 'ScholarlyWork')
        end
      end
    end
  end
end
