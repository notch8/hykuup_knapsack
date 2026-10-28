# frozen_string_literal: true

RSpec.describe DemoTenantResetService, singletenant: true do
  def account_named(name, public_demo_tenant: false)
    instance_double(Account, name:, cname: "#{name}.example.com", public_demo_tenant?: public_demo_tenant)
  end

  describe 'the demo tenant guard' do
    subject(:guard) { described_class.new(account:).send(:guard_demo_tenant!) }

    %w[ellison harborview meridian].each do |name|
      context "for the #{name} showcase tenant, which is not flagged public_demo_tenant" do
        let(:account) { account_named(name) }

        it('allows the reset') { expect { guard }.not_to raise_error }
      end
    end

    context 'for any other unflagged tenant' do
      let(:account) { account_named('acme-university') }

      it 'still refuses, since a reset wipes every work' do
        expect { guard }.to raise_error(described_class::NotDemoTenant, /acme-university.example.com/)
      end
    end

    context 'for a tenant whose name only contains a showcase name' do
      let(:account) { account_named('ellison-archive') }

      it('refuses') { expect { guard }.to raise_error(described_class::NotDemoTenant) }
    end

    context 'for a flagged public demo tenant' do
      let(:account) { account_named('sandbox', public_demo_tenant: true) }

      it('allows the reset as before') { expect { guard }.not_to raise_error }
    end
  end

  describe 'revoking visitor access' do
    subject(:revoke) { described_class.new(account:).send(:revoke_visitor_access!) }

    let(:site) { instance_double(Site) }
    let(:nick) { instance_double(User, email: 'nick@notch8.com') }

    before do
      allow(User).to receive(:joins).and_return(User.none)
      allow(Site).to receive(:instance).and_return(site)
    end

    context 'on a showcase tenant' do
      let(:account) { account_named('ellison') }

      it 'makes nick@notch8.com a superadmin' do
        allow(User).to receive(:find_by).with(email: 'nick@notch8.com').and_return(nick)
        allow(nick).to receive(:add_role)

        revoke

        expect(nick).to have_received(:add_role).with(:superadmin, site)
      end

      it "leaves everyone else's roles alone, since showcase tenants take no visitor signups" do
        allow(User).to receive(:find_by).and_return(nil)

        revoke

        expect(User).not_to have_received(:joins)
      end

      it 'carries on when the account does not exist on this environment' do
        allow(User).to receive(:find_by).with(email: 'nick@notch8.com').and_return(nil)

        expect { revoke }.not_to raise_error
      end
    end

    context 'on any other tenant' do
      let(:account) { account_named('sandbox', public_demo_tenant: true) }

      it 'grants nobody superadmin and clears visitor roles as before' do
        allow(User).to receive(:find_by)

        revoke

        expect(User).not_to have_received(:find_by)
        expect(User).to have_received(:joins)
      end
    end
  end
end
