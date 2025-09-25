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
    
    describe "tenant_allowed_work_types" do
      context "for UNCA tenant" do
        before do
          allow(Apartment::Tenant).to receive(:current).and_return('unca')
          account = double('Account', cname: 'unca.hykuup.com')
          allow(Account).to receive(:find_by).with(tenant: 'unca').and_return(account)
        end
        
        it "excludes MobiusWork" do
          allowed_types = controller_instance.send(:tenant_allowed_work_types)
          
          expect(allowed_types).to include('GenericWork', 'Image', 'Etd', 'Oer', 'ScholarlyWork', 'UncaWork')
          expect(allowed_types).not_to include('MobiusWork')
        end
      end
      
      context "for Mobius tenant" do
        before do
          allow(Apartment::Tenant).to receive(:current).and_return('mobius')
          account = double('Account', cname: 'example.digitalmobius.org')
          allow(Account).to receive(:find_by).with(tenant: 'mobius').and_return(account)
        end
        
        it "excludes UncaWork and ScholarlyWork" do
          allowed_types = controller_instance.send(:tenant_allowed_work_types)
          
          expect(allowed_types).to include('GenericWork', 'Image', 'Etd', 'Oer', 'MobiusWork')
          expect(allowed_types).not_to include('UncaWork', 'ScholarlyWork')
        end
      end
      
      context "for generic tenant" do
        before do
          allow(Apartment::Tenant).to receive(:current).and_return('generic')
          account = double('Account', cname: 'example.com')
          allow(Account).to receive(:find_by).with(tenant: 'generic').and_return(account)
        end
        
        it "excludes all tenant-specific work types" do
          allowed_types = controller_instance.send(:tenant_allowed_work_types)
          
          expect(allowed_types).to include('GenericWork', 'Image', 'Etd', 'Oer')
          expect(allowed_types).not_to include('MobiusWork', 'UncaWork', 'ScholarlyWork')
        end
      end
    end
  end
end
