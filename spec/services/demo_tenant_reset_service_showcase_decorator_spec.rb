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

  describe 'waiting for the import to finish' do
    subject(:pending) { described_class.new(account:).send(:pending_good_jobs) }

    before do
      %w[Bulkrax::ImportWorkJob ValkyrieCreateDerivativesJob].each do |job_class|
        GoodJob::Job.create!(id: SecureRandom.uuid, active_job_id: SecureRandom.uuid, queue_name: 'default',
                             job_class:, serialized_params: { 'tenant' => 'tenant-uuid' }, scheduled_at: 1.minute.ago)
      end
    end

    context 'on a showcase tenant' do
      let(:account) { instance_double(Account, name: 'meridian', cname: 'meridian.example.com', tenant: 'tenant-uuid') }

      it('waits for the Bulkrax jobs only, not the derivatives') { expect(pending).to eq 1 }
    end

    context 'on any other tenant' do
      let(:account) do
        instance_double(Account, name: 'sandbox', cname: 'sandbox.example.com', tenant: 'tenant-uuid', public_demo_tenant?: true)
      end

      it('waits for every job as before') { expect(pending).to eq 2 }
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

      it 'makes nick@notch8.com a superadmin before visitor roles are cleared, so his other roles survive' do
        allow(User).to receive(:find_by).with(email: 'nick@notch8.com').and_return(nick)
        expect(nick).to receive(:add_role).with(:superadmin, site).ordered
        expect(User).to receive(:joins).ordered.and_return(User.none)

        revoke
      end

      it 'carries on when the account does not exist on this environment' do
        allow(User).to receive(:find_by).with(email: 'nick@notch8.com').and_return(nil)

        expect { revoke }.not_to raise_error
      end
    end

    context 'on any other tenant' do
      let(:account) { account_named('sandbox', public_demo_tenant: true) }

      it 'grants nobody superadmin' do
        allow(User).to receive(:find_by)

        revoke

        expect(User).not_to have_received(:find_by)
      end
    end
  end
end
