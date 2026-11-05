# frozen_string_literal: true

RSpec.describe Ability do
  subject(:ability) { described_class.new(user) }

  let(:head_html) { ContentBlock.new(name: 'head_html') }
  let(:marketing) { ContentBlock.new(name: 'marketing_text') }

  context 'as a tenant admin' do
    let(:user) { create(:admin) }

    it 'may not update the head_html content block' do
      expect(ability.can?(:update, head_html)).to be false
    end

    it 'may still update the other content blocks' do
      expect(ability.can?(:update, marketing)).to be true
    end
  end

  context 'as a superadmin' do
    let(:user) { create(:superadmin) }

    it 'may update the head_html content block' do
      expect(ability.can?(:update, head_html)).to be true
    end
  end

  context 'as a tenant superadmin' do
    let(:user) { create(:admin).tap { |u| u.add_role(:superadmin, Site.instance) } }

    it 'may update the head_html content block' do
      expect(ability.can?(:update, head_html)).to be true
    end
  end
end
