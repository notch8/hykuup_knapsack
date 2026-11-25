# frozen_string_literal: true

RSpec.describe Admin::UsersController, type: :controller do
  describe 'POST #activate' do
    let(:inviter) { create(:admin) }
    let(:invitee) { User.invite!({ email: 'invitee@example.edu' }, inviter).tap { |u| u.add_role(:member, Site.instance) } }
    let(:mail) { ActionMailer::Base.deliveries.last }

    before do
      account = build(:account, tenant: 'FakeTenant', cname: 'tenant1')
      allow(account).to receive(:persisted?).and_return(true)
      allow(Account).to receive(:from_request).and_return(account)
      ActionMailer::Base.deliveries.clear
      sign_in inviter
    end

    it 'activates a pending user and emails them a set-password link' do
      post :activate, params: { id: invitee.id }

      expect(invitee.reload).to be_invitation_accepted
      expect(mail.to).to eq([invitee.email])
      expect(mail.body.encoded).to include('/users/password/edit?reset_password_token=')
    end

    it 'does not set the configured default password' do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with('HYKU_USER_DEFAULT_PASSWORD', nil).and_return('configured-default')

      post :activate, params: { id: invitee.id }

      expect(invitee.reload.valid_password?('configured-default')).to be(false)
    end

    it 'does not act on a user with no role in this repository' do
      outsider = User.invite!({ email: 'outsider@example.edu' }, inviter).tap { |u| u.roles.clear }
      ActionMailer::Base.deliveries.clear

      expect { post :activate, params: { id: outsider.id } }.to raise_error(ActiveRecord::RecordNotFound)

      expect(outsider.reload).not_to be_invitation_accepted
      expect(ActionMailer::Base.deliveries).to be_empty
    end

    it 'leaves an already-active user alone' do
      active = create(:user).tap { |u| u.add_role(:member, Site.instance) }
      digest = active.encrypted_password

      post :activate, params: { id: active.id }

      expect(active.reload.encrypted_password).to eq(digest)
      expect(ActionMailer::Base.deliveries).to be_empty
    end
  end
end
