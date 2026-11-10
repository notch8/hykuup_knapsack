# frozen_string_literal: true

RSpec.describe Hyrax::ContentBlocksController, type: :controller do
  subject(:value) { controller.send(:update_value_from_params) }

  before do
    controller.params = ActionController::Parameters.new(content_block: { head_html: '<script src="https://cmp.example.com/consent.js"></script>' })
    allow(controller).to receive(:can?).with(:update, having_attributes(name: 'head_html')).and_return(editor)
  end

  context 'for someone who may update the head_html block' do
    let(:editor) { true }

    it 'saves head_html' do
      expect(value).to eq '<script src="https://cmp.example.com/consent.js"></script>'
    end
  end

  context 'for anyone else' do
    let(:editor) { false }

    it 'ignores head_html' do
      expect(value).to be_nil
    end
  end
end
