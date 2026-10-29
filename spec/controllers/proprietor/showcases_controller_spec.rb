# frozen_string_literal: true

RSpec.describe Proprietor::ShowcasesController, type: :controller, multitenant: true do
  let(:user) {}
  let!(:showcase) { FactoryBot.create(:account, name: 'harborview', demo_tenant_snapshot: { 'captured_at' => '2026-10-28T23:10:05Z' }) }
  let!(:other) { FactoryBot.create(:account, name: 'pals') }

  before do
    sign_in user if user
    ActiveJob::Base.queue_adapter = :test
  end

  context 'as a tenant admin' do
    let(:user) { FactoryBot.create(:admin) }

    it 'refuses the page' do
      get :index
      expect(response).to be_redirect
    end

    it 'refuses a reset' do
      expect { post :reset, params: { id: showcase.id, confirm: 'harborview' } }.not_to have_enqueued_job
    end
  end

  context 'as a superadmin' do
    let(:user) { FactoryBot.create(:superadmin) }

    before { allow(Apartment::Tenant).to receive(:switch).and_yield }

    describe 'GET #index' do
      render_views

      it 'lists only the showcase tenants, each with its buttons' do
        get :index
        expect(assigns(:showcases).map(&:name)).to eq ['harborview']
        expect(response.body).to include(snapshot_proprietor_showcase_path(showcase), reset_proprietor_showcase_path(showcase))
      end

      it 'offers no reset before a look is saved' do
        showcase.update!(demo_tenant_snapshot: nil)
        get :index
        expect(response.body).not_to include(reset_proprietor_showcase_path(showcase))
      end
    end

    it 'saves the look in the background, in the tenant' do
      expect { post :snapshot, params: { id: showcase.id } }.to have_enqueued_job(ShowcaseSnapshotJob)
      expect(Apartment::Tenant).to have_received(:switch).with(showcase.tenant)
    end

    it 'resets once the name is typed' do
      expect { post :reset, params: { id: showcase.id, confirm: 'harborview' } }
        .to have_enqueued_job(ShowcaseResetJob)
      expect(flash[:notice]).to include 'Resetting harborview'
    end

    it 'does not reset when the name is mistyped' do
      expect { post :reset, params: { id: showcase.id, confirm: 'harbor' } }.not_to have_enqueued_job
      expect(flash[:error]).to include 'Type harborview exactly'
    end

    it 'does not reset a tenant with no saved look' do
      showcase.update!(demo_tenant_snapshot: nil)

      expect { post :reset, params: { id: showcase.id, confirm: 'harborview' } }.not_to have_enqueued_job
      expect(flash[:error]).to include 'no saved look'
    end

    it 'does not start a second job while one runs' do
      allow_any_instance_of(ShowcaseTenant).to receive(:saving_or_resetting?).and_return(true) # rubocop:disable RSpec/AnyInstance

      expect { post :snapshot, params: { id: showcase.id } }.not_to have_enqueued_job
      expect(flash[:error]).to include 'already saving or resetting'
    end

    context 'while video thumbnails are being put back' do
      before { allow_any_instance_of(ShowcaseTenant).to receive(:restoring_thumbnails?).and_return(true) } # rubocop:disable RSpec/AnyInstance

      it 'does not save the look, which would keep the automatic thumbnails' do
        expect { post :snapshot, params: { id: showcase.id } }.not_to have_enqueued_job
        expect(flash[:error]).to include 'still being put back'
      end

      it 'still resets' do
        expect { post :reset, params: { id: showcase.id, confirm: 'harborview' } }.to have_enqueued_job(ShowcaseResetJob)
      end
    end

    it 'never touches a tenant that is not a showcase' do
      expect { post :reset, params: { id: other.id, confirm: 'pals' } }
        .to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
