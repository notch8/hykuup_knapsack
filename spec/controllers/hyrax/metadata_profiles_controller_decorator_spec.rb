# frozen_string_literal: true

RSpec.describe Hyrax::MetadataProfilesController, singletenant: true do
  describe "tenant-specific profile validation" do
    let(:controller_instance) { described_class.new }

    before do
      # Ensure all work types are registered
      allow(Hyrax.config).to receive(:registered_curation_concern_types).and_return([
                                                                                      'GenericWork', 'Image', 'Etd', 'Oer', 'MobiusWork', 'UncaWork', 'ScholarlyWork'
                                                                                    ])
    end

    describe "validate_tenant_work_types!" do
      context "for UNCA tenant" do
        before do
          allow(Apartment::Tenant).to receive(:current).and_return('unca')
          account = double('Account', cname: 'unca.hykuup.com', part_of_consortia: 'unca')
          allow(Account).to receive(:find_by).with(tenant: 'unca').and_return(account)
        end

        it "allows profiles with UNCA-allowed work types" do
          profile_data = {
            'classes' => {
              'GenericWorkResource' => {},
              'ScholarlyWorkResource' => {}
            }
          }

          expect { controller_instance.send(:validate_tenant_work_types!, profile_data) }.not_to raise_error
        end

        it "rejects profiles with MobiusWork and provides helpful error message" do
          profile_data = {
            'classes' => {
              'GenericWorkResource' => {},
              'MobiusWorkResource' => {}
            }
          }

          expect { controller_instance.send(:validate_tenant_work_types!, profile_data) }
            .to raise_error(StandardError, /This profile contains work types \(MobiusWork\) that are not allowed for unca\.hykuup\.com/)
        end

        it "rejects profiles with UncaWork and provides helpful error message" do
          profile_data = {
            'classes' => {
              'GenericWorkResource' => {},
              'UncaWorkResource' => {}
            }
          }

          expect { controller_instance.send(:validate_tenant_work_types!, profile_data) }
            .to raise_error(StandardError, /This profile contains work types \(UncaWork\) that are not allowed for unca\.hykuup\.com/)
        end

        it "includes allowed work types in error message" do
          profile_data = {
            'classes' => {
              'MobiusWorkResource' => {}
            }
          }

          expect { controller_instance.send(:validate_tenant_work_types!, profile_data) }
            .to raise_error(StandardError, /Allowed work types for unca\.hykuup\.com: GenericWork, Image, Etd, Oer, ScholarlyWork/)
        end
      end

      context "for Mobius tenant" do
        before do
          allow(Apartment::Tenant).to receive(:current).and_return('mobius')
          account = double('Account', cname: 'example.digitalmobius.org', part_of_consortia: 'mobius')
          allow(Account).to receive(:find_by).with(tenant: 'mobius').and_return(account)
        end

        it "allows profiles with Mobius-allowed work types" do
          profile_data = {
            'classes' => {
              'GenericWorkResource' => {},
              'MobiusWorkResource' => {}
            }
          }

          expect { controller_instance.send(:validate_tenant_work_types!, profile_data) }.not_to raise_error
        end

        it "rejects profiles with UncaWork and ScholarlyWork" do
          profile_data = {
            'classes' => {
              'GenericWorkResource' => {},
              'UncaWorkResource' => {},
              'ScholarlyWorkResource' => {}
            }
          }

          expect { controller_instance.send(:validate_tenant_work_types!, profile_data) }
            .to raise_error(StandardError, /This profile contains work types \(UncaWork, ScholarlyWork\) that are not allowed for example\.digitalmobius\.org/)
        end

        it "includes allowed work types in error message" do
          profile_data = {
            'classes' => {
              'UncaWorkResource' => {}
            }
          }

          expect { controller_instance.send(:validate_tenant_work_types!, profile_data) }
            .to raise_error(StandardError, /Allowed work types for example\.digitalmobius\.org: GenericWork, Image, Etd, Oer, MobiusWork/)
        end
      end

      context "for generic tenant" do
        before do
          allow(Apartment::Tenant).to receive(:current).and_return('generic')
          account = double('Account', cname: 'example.com', part_of_consortia: nil)
          allow(Account).to receive(:find_by).with(tenant: 'generic').and_return(account)
        end

        it "allows profiles with only generic work types" do
          profile_data = {
            'classes' => {
              'GenericWorkResource' => {},
              'ImageResource' => {},
              'EtdResource' => {},
              'OerResource' => {}
            }
          }

          expect { controller_instance.send(:validate_tenant_work_types!, profile_data) }.not_to raise_error
        end

        it "rejects profiles with any tenant-specific work types" do
          profile_data = {
            'classes' => {
              'MobiusWorkResource' => {},
              'UncaWorkResource' => {},
              'ScholarlyWorkResource' => {}
            }
          }
          expect { controller_instance.send(:validate_tenant_work_types!, profile_data) }
            .to raise_error(StandardError, /This profile contains work types \(MobiusWork, UncaWork, ScholarlyWork\) that are not allowed for example\.com/)
        end

        it "includes allowed work types in error message" do
          profile_data = {
            'classes' => { 'MobiusWorkResource' => {} }
          }
          expect { controller_instance.send(:validate_tenant_work_types!, profile_data) }
            .to raise_error(StandardError, /Allowed work types for example\.com: GenericWork, Image, Etd, Oer/)
        end
      end

      context "when tenant name is not available" do
        before do
          allow(Apartment::Tenant).to receive(:current).and_return(nil)
          allow(Account).to receive(:find_by).with(tenant: nil).and_return(nil)
        end

        it "uses fallback tenant name in error message" do
          profile_data = {
            'classes' => {
              'MobiusWorkResource' => {}
            }
          }

          expect { controller_instance.send(:validate_tenant_work_types!, profile_data) }
            .to raise_error(StandardError, /This profile contains work types \(MobiusWork\) that are not allowed for this tenant/)
        end

        it "includes allowed work types in error message with fallback tenant name" do
          profile_data = {
            'classes' => {
              'MobiusWorkResource' => {}
            }
          }

          expect { controller_instance.send(:validate_tenant_work_types!, profile_data) }
            .to raise_error(StandardError, /Allowed work types for this tenant: GenericWork, Image, Etd, Oer/)
        end
      end
    end

    describe "tenant_allowed_work_types" do
      context "for UNCA tenant" do
        before do
          allow(Apartment::Tenant).to receive(:current).and_return('unca')
          account = double('Account', cname: 'unca.hykuup.com', part_of_consortia: 'unca')
          allow(Account).to receive(:find_by).with(tenant: 'unca').and_return(account)
        end

        it "returns all work types except MobiusWork and UncaWork" do
          allowed_types = TenantWorkTypeFilter.allowed_work_types

          expect(allowed_types).to include('GenericWork', 'Image', 'Etd', 'Oer', 'ScholarlyWork')
          expect(allowed_types).not_to include('MobiusWork', 'UncaWork')
        end
      end

      context "for Mobius tenant" do
        before do
          allow(Apartment::Tenant).to receive(:current).and_return('mobius')
          account = double('Account', cname: 'example.digitalmobius.org', part_of_consortia: 'mobius')
          allow(Account).to receive(:find_by).with(tenant: 'mobius').and_return(account)
        end

        it "returns all work types except UncaWork and ScholarlyWork" do
          allowed_types = TenantWorkTypeFilter.allowed_work_types

          expect(allowed_types).to include('GenericWork', 'Image', 'Etd', 'Oer', 'MobiusWork')
          expect(allowed_types).not_to include('UncaWork', 'ScholarlyWork')
        end
      end

      context "for generic tenant" do
        before do
          allow(Apartment::Tenant).to receive(:current).and_return('generic')
          account = double('Account', cname: 'example.com', part_of_consortia: nil)
          allow(Account).to receive(:find_by).with(tenant: 'generic').and_return(account)
        end

        it "returns only generic work types" do
          allowed_types = TenantWorkTypeFilter.allowed_work_types

          expect(allowed_types).to include('GenericWork', 'Image', 'Etd', 'Oer')
          expect(allowed_types).not_to include('MobiusWork', 'UncaWork', 'ScholarlyWork')
        end
      end
    end
  end
end
