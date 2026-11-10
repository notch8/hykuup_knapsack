# frozen_string_literal: true

RSpec.describe 'hyrax/content_blocks/_form.html.erb', type: :view do
  before do
    without_partial_double_verification { allow(view).to receive(:head_html_editor?).and_return(editor) }
    render
  end

  context 'for a superadmin' do
    let(:editor) { true }

    it 'offers a plain-text Head HTML tab' do
      page = Capybara.string(rendered)
      expect(page).to have_link('Head HTML', href: '#head_html')
      expect(page).to have_css('#head_html textarea[name="content_block[head_html]"]:not(.tinymce)')
    end
  end

  context 'for a tenant admin' do
    let(:editor) { false }

    it 'hides the Head HTML tab' do
      expect(rendered).not_to include 'head_html'
    end
  end
end
