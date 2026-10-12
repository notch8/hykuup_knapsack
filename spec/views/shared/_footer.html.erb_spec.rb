# frozen_string_literal: true

RSpec.describe 'shared/_footer.html.erb', type: :view do
  before do
    allow(view).to receive(:user_signed_in?).and_return(false)
    stub_template 'hyrax/base/_privacy_policy.html.erb' => ''
  end

  %w[en es pt-BR de it zh fr].each do |locale|
    context "in the #{locale} locale" do
      around { |example| I18n.with_locale(locale) { example.run } }

      it 'credits Notch8 with a link that opens in a new tab' do
        render

        link = Capybara.string(rendered).find_link('Notch8')
        expect(link[:href]).to eq 'https://www.notch8.com/'
        expect(link[:target]).to eq '_blank'
        expect(link[:rel]).to eq 'noopener noreferrer'
        expect(rendered).not_to include 'Samvera</a>'
      end
    end
  end
end
