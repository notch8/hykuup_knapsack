# frozen_string_literal: true

RSpec.describe DemoTenantResetService, singletenant: true do
  subject(:guard) { described_class.new(account:).send(:guard_demo_tenant!) }

  def account_named(name, public_demo_tenant: false)
    instance_double(Account, name:, cname: "#{name}.example.com", public_demo_tenant?: public_demo_tenant)
  end

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
