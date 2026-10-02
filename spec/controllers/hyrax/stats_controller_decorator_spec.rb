# frozen_string_literal: true

require 'rails_helper'

# The :hyrax_work factory builds Hyrax::Test::SimpleWork, which hyrax-webapp's rails_helper loads but the knapsack's doesn't.
require Hyrax::Engine.root.join('lib/hyrax/specs/shared_specs/simple_work.rb').to_s unless Hyrax.config.disable_wings

RSpec.describe Hyrax::StatsController, type: :controller do
  routes { Hyrax::Engine.routes }
  render_views

  let(:user) { create(:admin) }
  let(:error) { Google::Cloud::PermissionDeniedError.new('User does not have sufficient permissions for this property.') }

  # The knapsack's rails_helper doesn't load Hyku's fake-tenant setup, so stub the account lookup
  # the same way uploads_controller_decorator_spec does.
  let(:account) do
    FactoryBot.build(:account, tenant: 'FakeTenant', cname: 'tenant1').tap do |acct|
      allow(acct).to receive(:persisted?).and_return(true)
    end
  end

  before do
    allow(Account).to receive(:from_request).and_return(account)
    allow(Site).to receive(:account).and_return(account)
    sign_in user
  end

  describe '#file' do
    let(:file_set) { valkyrie_create(:hyrax_file_set, depositor: user.user_key, date_uploaded: 3.days.ago) }

    before { allow(Hyrax::Analytics).to receive(:page_statistics).and_raise(error) }

    it 'renders zeroed stats with a notice instead of raising' do
      get :file, params: { id: file_set.id }
      expect(response).to be_successful
      expect(response.body).to include(CGI.escapeHTML(I18n.t('hyrax.admin.analytics.errors.permission.message')))
      expect(assigns(:stats).total_pageviews).to eq 0
    end
  end

  describe '#work' do
    let(:work) { valkyrie_create(:generic_work_resource, depositor: user.user_key) }

    before { allow(Hyrax::Analytics).to receive(:daily_events_for_id).and_raise(error) }

    it 'renders zeroed stats with a notice instead of raising' do
      get :work, params: { id: work.id }
      expect(response).to be_successful
      expect(response.body).to include(CGI.escapeHTML(I18n.t('hyrax.admin.analytics.errors.permission.message')))
      expect(assigns(:pageviews).all).to eq 0
    end

    context 'with a non-permission Google error' do
      let(:error) { Google::Cloud::InvalidArgumentError.new('Invalid property') }

      it 'uses the general notice' do
        get :work, params: { id: work.id }
        expect(response.body).to include('problem with the Google Analytics configuration')
      end
    end
  end
end
