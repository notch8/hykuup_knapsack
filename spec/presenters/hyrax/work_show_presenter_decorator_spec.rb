# frozen_string_literal: true

RSpec.describe Hyrax::WorkShowPresenterDecorator do
  subject(:presenter) { Hyrax::WorkShowPresenter.new(solr_document, nil) }

  let(:solr_document) do
    SolrDocument.new(id: 'abc123', title_tesim: ['Notes Toward a Thesis'],
                     human_readable_type_tesim: [human_readable_type])
  end
  let(:human_readable_type) { 'Generic Work' }

  context 'when the tenant has an application name' do
    before { allow(Site).to receive(:application_name).and_return('Ellison Institutional Repository') }

    it 'ends the title with the tenant name, not the product name' do
      expect(presenter.page_title).to eq 'Notes Toward a Thesis | ID: abc123 | Ellison Institutional Repository'
    end

    context 'for a work type other than Generic Work' do
      let(:human_readable_type) { 'Image' }

      it 'leads with the work type' do
        expect(presenter.page_title).to eq 'Image | Notes Toward a Thesis | ID: abc123 | Ellison Institutional Repository'
      end
    end
  end

  context 'when the tenant has no application name' do
    before { allow(Site).to receive(:application_name).and_return(nil) }

    it 'falls back to the product name' do
      expect(presenter.page_title).to end_with "| #{I18n.t('hyrax.product_name')}"
    end
  end
end
