# frozen_string_literal: true

RSpec.describe TenantWorkTypeFilter, singletenant: true do
  let(:default_path) { '/path/to/default/profile.yaml' }

  before do
    # Ensure all work types are registered
    allow(Hyrax.config).to receive(:registered_curation_concern_types).and_return([
                                                                                    'GenericWork', 'Image', 'Etd', 'Oer', 'MobiusWork', 'ScholarlyWork'
                                                                                  ])
  end

  describe '.excluded_work_types' do
    context 'for UNCA tenant' do
      before do
        allow(Apartment::Tenant).to receive(:current).and_return('unca')
        account = double('Account', part_of_consortia: 'unca', cname: 'unca.hykuup.com')
        allow(Account).to receive(:find_by).with(tenant: 'unca').and_return(account)
      end

      it 'returns MobiusWork as excluded' do
        excluded_types = described_class.excluded_work_types
        expect(excluded_types).to eq(%w[MobiusWork])
      end
    end

    context 'for Mobius tenant' do
      before do
        allow(Apartment::Tenant).to receive(:current).and_return('mobius')
        account = double('Account', part_of_consortia: 'mobius', cname: 'example.digitalmobius.org')
        allow(Account).to receive(:find_by).with(tenant: 'mobius').and_return(account)
      end

      it 'returns ScholarlyWork as excluded' do
        excluded_types = described_class.excluded_work_types
        expect(excluded_types).to eq(%w[ScholarlyWork])
      end
    end

    context 'for generic tenant' do
      before do
        allow(Apartment::Tenant).to receive(:current).and_return('generic')
        account = double('Account', part_of_consortia: nil, cname: 'example.com')
        allow(Account).to receive(:find_by).with(tenant: 'generic').and_return(account)
      end

      it 'returns all tenant-specific work types as excluded' do
        excluded_types = described_class.excluded_work_types
        expect(excluded_types).to eq(%w[MobiusWork ScholarlyWork])
      end
    end
  end

  describe '.allowed_work_types' do
    context 'for UNCA tenant' do
      before do
        allow(Apartment::Tenant).to receive(:current).and_return('unca')
        account = double('Account', part_of_consortia: 'unca', cname: 'unca.hykuup.com')
        allow(Account).to receive(:find_by).with(tenant: 'unca').and_return(account)
      end

      it 'excludes MobiusWork' do
        allowed_types = described_class.allowed_work_types

        expect(allowed_types).to include('GenericWork', 'Image', 'Etd', 'Oer', 'ScholarlyWork')
        expect(allowed_types).not_to include('MobiusWork')
      end
    end

    context 'for Mobius tenant' do
      before do
        allow(Apartment::Tenant).to receive(:current).and_return('mobius')
        account = double('Account', part_of_consortia: 'mobius', cname: 'example.digitalmobius.org')
        allow(Account).to receive(:find_by).with(tenant: 'mobius').and_return(account)
      end

      it 'excludes ScholarlyWork' do
        allowed_types = described_class.allowed_work_types

        expect(allowed_types).to include('GenericWork', 'Image', 'Etd', 'Oer', 'MobiusWork')
        expect(allowed_types).not_to include('ScholarlyWork')
      end
    end

    context 'for generic tenant' do
      before do
        allow(Apartment::Tenant).to receive(:current).and_return('generic')
        account = double('Account', part_of_consortia: nil, cname: 'example.com')
        allow(Account).to receive(:find_by).with(tenant: 'generic').and_return(account)
      end

      it 'excludes all tenant-specific work types' do
        allowed_types = described_class.allowed_work_types

        expect(allowed_types).to include('GenericWork', 'Image', 'Etd', 'Oer')
        expect(allowed_types).not_to include('MobiusWork', 'ScholarlyWork')
      end
    end
  end

  describe '.tenant_metadata_profile_path' do
    context 'when cname is nil' do
      before do
        allow(Apartment::Tenant).to receive(:current).and_return(nil)
      end

      it 'returns the default path' do
        result = described_class.tenant_metadata_profile_path(default_path)
        expect(result).to eq(default_path)
      end
    end

    context 'when cname includes "unca"' do
      before do
        allow(Apartment::Tenant).to receive(:current).and_return('unca')
        account = double('Account', part_of_consortia: 'unca', cname: 'unca.hykuup.com')
        allow(Account).to receive(:find_by).with(tenant: 'unca').and_return(account)
      end

      it 'returns the UNCA profile path' do
        result = described_class.tenant_metadata_profile_path(default_path)
        expected_path = HykuKnapsack::Engine.root.join('config', 'metadata_profiles', 'unca', 'm3_profile.yaml')
        expect(result).to eq(expected_path)
      end
    end

    context 'when cname includes "unca" in a different domain' do
      before do
        allow(Apartment::Tenant).to receive(:current).and_return('unca-test')
        account = double('Account', part_of_consortia: 'unca', cname: 'unca-test.example.com')
        allow(Account).to receive(:find_by).with(tenant: 'unca-test').and_return(account)
      end

      it 'returns the UNCA profile path' do
        result = described_class.tenant_metadata_profile_path(default_path)
        expected_path = HykuKnapsack::Engine.root.join('config', 'metadata_profiles', 'unca', 'm3_profile.yaml')
        expect(result).to eq(expected_path)
      end
    end

    context 'when cname includes "mobius"' do
      before do
        allow(Apartment::Tenant).to receive(:current).and_return('mobius')
        account = double('Account', part_of_consortia: 'mobius', cname: 'example.digitalmobius.org')
        allow(Account).to receive(:find_by).with(tenant: 'mobius').and_return(account)
      end

      it 'returns the Mobius profile path' do
        result = described_class.tenant_metadata_profile_path(default_path)
        expected_path = HykuKnapsack::Engine.root.join('config', 'metadata_profiles', 'mobius', 'm3_profile.yaml')
        expect(result).to eq(expected_path)
      end
    end

    context 'when cname includes "mobius" in a different domain' do
      before do
        allow(Apartment::Tenant).to receive(:current).and_return('mobius-test')
        account = double('Account', part_of_consortia: 'mobius', cname: 'mobius-test.example.com')
        allow(Account).to receive(:find_by).with(tenant: 'mobius-test').and_return(account)
      end

      it 'returns the Mobius profile path' do
        result = described_class.tenant_metadata_profile_path(default_path)
        expected_path = HykuKnapsack::Engine.root.join('config', 'metadata_profiles', 'mobius', 'm3_profile.yaml')
        expect(result).to eq(expected_path)
      end
    end

    context 'when cname does not include "unca" or "mobius"' do
      before do
        allow(Apartment::Tenant).to receive(:current).and_return('generic')
        account = double('Account', part_of_consortia: nil, cname: 'example.com')
        allow(Account).to receive(:find_by).with(tenant: 'generic').and_return(account)
      end

      it 'returns the default path' do
        result = described_class.tenant_metadata_profile_path(default_path)
        expect(result).to eq(default_path)
      end
    end
  end
end
