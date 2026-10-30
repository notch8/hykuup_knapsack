# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Hyrax::GenericWorksController, type: :controller do
  let(:user) { FactoryBot.create(:user) }
  # Same tenant stub as uploads_controller_decorator_spec: the knapsack's rails_helper does not
  # load Hyku's multitenancy support, and require_active_account! needs an account.
  let(:account) do
    FactoryBot.build(:account, tenant: 'FakeTenant', cname: 'tenant1').tap do |acct|
      allow(acct).to receive(:persisted?).and_return(true)
    end
  end

  before do
    allow(Account).to receive(:from_request).and_return(account)
    allow(Site).to receive(:account).and_return(account)
    allow(Rails.env).to receive(:test?).and_return(false)
    allow(Account).to receive(:global_tenant?).and_return(false)
  end

  it "sits between every work controller's own actions and Hyrax's" do
    Hyrax.config.registered_curation_concern_types.each do |type|
      ancestors = "Hyrax::#{type.pluralize}Controller".constantize.ancestors
      expect(ancestors.index(Hyrax::WorksControllerRevalidationDecorator)).to be < ancestors.index(Hyrax::WorksControllerBehavior)
    end
  end

  describe "#manifest" do
    let(:solr_document) { SolrDocument.new(id: 'work-1', has_model_ssim: ['GenericWork']) }

    before do
      allow(controller).to receive(:search_result_document).and_return(solr_document)
      allow(::Ability).to receive(:new).and_call_original
      allow(::Ability).to receive(:new).with(nil).and_return(instance_double(Ability, can?: true))
      allow(controller).to receive(:iiif_manifest_builder).and_return(instance_double(Hyrax::ManifestBuilderService, manifest_for: {}))
      get :manifest, params: { id: solr_document.id }, format: :json
    end

    it "answers a browser revalidating its copy with 304 rather than rendering the manifest again" do
      expect(response).to have_http_status(:ok)

      request.headers['If-None-Match'] = response.headers['ETag']
      get :manifest, params: { id: solr_document.id }, format: :json

      expect(response).to have_http_status(:not_modified)
      expect(response.body).to be_empty
    end
  end

  describe "#show" do
    # Stands in for fresh_when finding the browser's copy current; the first, full render
    # needs a persisted work, which the manifest example already covers end to end.
    before do
      allow(controller).to receive(:search_result_document)
        .and_return(SolrDocument.new(id: 'work-1', has_model_ssim: ['GenericWork'], visibility_ssi: 'open'))
      allow(controller).to receive(:load_curation_concern).and_return(GenericWorkResource.new(id: 'work-1'))
      allow(controller).to receive(:fresh_when) { controller.head :not_modified }
    end

    it "does not render again once the browser's copy is found current" do
      get :show, params: { id: 'work-1' }, format: :json

      expect(response).to have_http_status(:not_modified)
    end
  end
end
