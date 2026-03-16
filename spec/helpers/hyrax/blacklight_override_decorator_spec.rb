# frozen_string_literal: true

# Spec to verify that catalog display labels respect the current locale when
# using flexible metadata. Without the fix, load_flexible_schema freezes labels
# at boot-time (default :en) locale and custom_label: true short-circuits any
# future i18n resolution.
RSpec.describe Hyrax::BlacklightOverride, type: :helper do
  include Hyrax::BlacklightOverride

  let(:profile_path) { HykuKnapsack::Engine.root.join('config', 'metadata_profiles', 'default', 'm3_profile.yaml') }
  let(:profile) { YAML.safe_load_file(profile_path) }

  # Snapshot class-level blacklight_config label state before mutating it,
  # so we can restore it after — load_flexible_schema mutates shared class state.
  let(:original_labels) do
    CatalogController.blacklight_config.index_fields.transform_values { |f| [f.label, f.custom_label] }
  end

  before do
    original_labels # evaluate before mutation

    Hyrax::FlexibleSchema.delete_all
    Hyrax::FlexibleSchema.create!(profile:)

    # Simulate the cold-cache condition caused by load_translations! -> backend.reload!
    # by forcing load_flexible_schema to run while the locale is :en (boot default),
    # which is what happens in production before before_action :set_locale fires.
    I18n.with_locale(:en) do
      CatalogController.load_flexible_schema
    end
  end

  after do
    original_labels.each do |name, (label, custom_label)|
      field = CatalogController.blacklight_config.index_fields[name]
      next unless field
      field.label = label
      field.custom_label = custom_label
    end
  end

  # 'title_tesim' is present in every profile with multi-locale display_label entries.
  let(:field_name) { 'title_tesim' }
  let(:document) { instance_double(SolrDocument, to_h: {}) }

  def index_fields(_document)
    CatalogController.blacklight_config.index_fields
  end

  context "when locale is :en" do
    it "returns the English label" do
      I18n.with_locale(:en) do
        expect(index_field_label(document, field_name)).to include("Title")
      end
    end
  end

  context "when locale is :es after schema was loaded in :en" do
    it "returns the Spanish label" do
      I18n.with_locale(:es) do
        expect(index_field_label(document, field_name)).to include("Título")
      end
    end
  end
end
