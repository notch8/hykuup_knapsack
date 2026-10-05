# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Hyrax::FormHelperBehaviorDecorator, type: :helper do
  before { allow(helper).to receive(:controlled_vocabulary_source_for).with(:mesh_subject).and_return('mesh') }

  it 'offers a mesh-sourced property as autocomplete instead of raising' do
    config = helper.controlled_vocabulary_options_for(:mesh_subject)

    expect(config).to eq(type: 'autocomplete', url: '/authorities/search/local/mesh')
  end
end
