# frozen_string_literal: true

RSpec.describe '_head_tag_extras.html.erb', type: :view do
  let(:head_html) { '<script src="https://cmp.example.com/consent.js"></script>' }
  let(:turbolinks_reload) { 'meta[name="head-html"][data-turbolinks-track="reload"]' }
  let(:visit_reload) { 'meta[name="turbolinks-visit-control"][content="reload"]' }

  before do
    allow(view).to receive(:block_for).with(name: 'head_html').and_return(head_html)
    without_partial_double_verification { allow(view).to receive(:public_demo_tenant?).and_return(false) }
    allow(controller).to receive(:_layout).and_return(layout)
  end

  context 'on a public page' do
    let(:layout) { 'hyrax/1_column' }

    it 'renders the head_html' do
      render

      expect(rendered).to include '<script src="https://cmp.example.com/consent.js"></script>'
    end

    it 'makes Turbolinks reload when the head_html changes' do
      render

      expect(Capybara.string(rendered)).to have_css("meta[name='head-html'][content='#{Digest::SHA256.hexdigest(head_html)}']", visible: :all)
    end

    it 'makes Turbolinks reload when crossing to or from the dashboard' do
      render

      expect(Capybara.string(rendered)).to have_css(turbolinks_reload, visible: :all)
    end

    it 'makes every visit a full load so the head_html runs on each page' do
      render

      expect(Capybara.string(rendered)).to have_css(visit_reload, visible: :all)
    end

    context 'without head_html' do
      let(:head_html) { nil }

      it 'leaves Turbolinks navigation alone' do
        render

        expect(Capybara.string(rendered)).not_to have_css(turbolinks_reload, visible: :all)
        expect(Capybara.string(rendered)).not_to have_css(visit_reload, visible: :all)
      end
    end
  end

  context 'on a dashboard page' do
    let(:layout) { 'hyrax/dashboard' }

    it 'leaves the head_html out' do
      render

      expect(rendered).not_to include 'cmp.example.com'
      expect(Capybara.string(rendered)).not_to have_css(turbolinks_reload, visible: :all)
    end
  end
end
