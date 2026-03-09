# frozen_string_literal: true

# Service to migrate an M3 profile from the legacy m3.yml format to the
# current config/metadata_profiles/default/m3_profile.yaml conventions.
#
# Transformations applied:
#   1. display_label normalization via Hyrax::M3ProfileEditor (same as
#      hyrax:metadata:update_labels rake task)
#   2. render_as: faceted conversion — determined by inspecting each property:
#      - Has a _sim indexing entry → render_as: linked + adds "facetable" to indexing
#      - No _sim indexing entry    → removes render_as entirely (field is not Solr-facetable)
#   3. Splits rights_statement: removes Hyrax::FileSet and CollectionResource
#      from its available_on classes and adds a rights_statement_optional alias
#      property covering those two classes (idempotent)
#
# Usage:
#
#   1. Migrate a file and save it back in place (or to a different output path):
#
#      service = M3ProfileMigrationService.new(HykuKnapsack::Engine.root.join('m3.yml'))
#      service.migrate
#
#      # Or save to a different location:
#      service = M3ProfileMigrationService.new(source_path, output_path)
#      service.migrate
#
#   2. Migrate a file, validate, and return the result Hash without saving:
#      Raises RuntimeError if validation fails.
#
#      service = M3ProfileMigrationService.new(HykuKnapsack::Engine.root.join('m3.yml'))
#      service.migrate_without_saving
#
#   3. Migrate an already-loaded profile Hash (e.g. from a FlexibleSchema record),
#      validate, and return the result without saving to any file:
#      Raises RuntimeError if validation fails.
#
#      service = M3ProfileMigrationService.new_from_data(Hyrax::FlexibleSchema.last.profile)
#      service.migrate_without_saving
class M3ProfileMigrationService
  # Classes to move from rights_statement to rights_statement_optional.
  RIGHTS_STATEMENT_OPTIONAL_CLASSES = %w[Hyrax::FileSet CollectionResource].freeze

  # Initialize from a file path.
  def initialize(source_path, output_path = nil)
    @source_path = source_path.to_s
    @output_path = (output_path || source_path).to_s
  end

  # Initialize from an already-loaded profile Hash (e.g. from a FlexibleSchema record).
  # When using this constructor, calling +migrate+ (which saves to a file) is not supported;
  # use +migrate_without_saving+ instead.
  def self.new_from_data(profile_data)
    instance = allocate
    instance.instance_variable_set(:@profile_data_override, profile_data.deep_dup)
    instance
  end

  # Applies all migration transformations, validates, and saves to output_path.
  def migrate
    transform
    save
  end

  # Applies all migration transformations and validates without saving.
  # Returns the transformed profile data for inspection.
  def migrate_without_saving
    transform
    validate!
    profile_data
  end

  private

  def transform
    normalize_display_labels
    convert_faceted_render_as
    split_rights_statement
  end

  # Step 1: Normalize display_label fields using Hyrax::M3ProfileEditor.
  # This mirrors the hyrax:metadata:update_labels rake task logic.
  def normalize_display_labels
    # Force i18n to load all blacklight show/index field translations so that
    # reverse lookups in find_i18n resolve correctly.
    I18n.t('blacklight.search.fields.show')
    I18n.t('blacklight.search.fields.index')

    profile_data['properties'].each do |property_name, property_data|
      normalize_property_display_label(property_name, property_data)
    end
  end

  def normalize_property_display_label(property_name, property_data)
    default_label = extract_default_label(property_name, property_data)
    existing_hash = extract_existing_label_hash(property_data)

    profile_data['properties'][property_name]['display_label'] = existing_hash.presence || {}
    profile_data['properties'][property_name]['display_label']['default'] = find_i18n(default_label)
    profile_data['properties'][property_name]['view']&.delete('label')
  end

  def extract_default_label(property_name, property_data)
    case property_data['display_label']
    when String then property_data['display_label']
    when Hash   then property_data['display_label']['default']
    else             property_name.humanize
    end
  end

  def extract_existing_label_hash(property_data)
    existing = property_data['view']&.fetch('label', nil)
    existing = nil if !existing.is_a?(Hash) || existing.keys.size <= 1
    existing ||= property_data['display_label'] if multilingual_hash?(property_data['display_label'])
    existing
  end

  def multilingual_hash?(value)
    value.is_a?(Hash) && value.keys.size > 1
  end

  # Step 2: Convert render_as: faceted for each property based on its indexing.
  # Whether a property should be Solr-facetable is determined by the presence of
  # a _sim indexing entry — no hardcoded property name lists needed.
  #
  # - Has a _sim indexing entry → render_as: linked + "facetable" added to indexing
  # - No _sim indexing entry    → render_as removed (field is not Solr-facetable)
  def convert_faceted_render_as
    profile_data['properties'].each do |_property_name, property_data|
      view = property_data['view']
      next unless view.is_a?(Hash) && view['render_as'] == 'faceted'

      if facetable_by_indexing?(property_data)
        view['render_as'] = 'linked'
        add_facetable_to_indexing(property_data)
      else
        view.delete('render_as')
      end
    end
  end

  # A property is Solr-facetable if it already has a _sim index entry.
  def facetable_by_indexing?(property_data)
    (property_data['indexing'] || []).any? { |entry| entry.end_with?('_sim') }
  end

  def add_facetable_to_indexing(property_data)
    property_data['indexing'] ||= []
    property_data['indexing'] << 'facetable' unless property_data['indexing'].include?('facetable')
  end

  # Step 3: Split rights_statement into main property + rights_statement_optional alias.
  # Removes Hyrax::FileSet and CollectionResource from main rights_statement available_on.
  # Adds rights_statement_optional if not already present.
  def split_rights_statement
    rs = profile_data['properties']['rights_statement']
    return unless rs

    available_classes = rs.dig('available_on', 'class') || []
    optional_classes = available_classes & RIGHTS_STATEMENT_OPTIONAL_CLASSES
    return if optional_classes.empty?

    # Remove optional classes from main rights_statement
    rs['available_on']['class'] = available_classes - RIGHTS_STATEMENT_OPTIONAL_CLASSES

    # Add rights_statement_optional alias only if not already present
    return if profile_data['properties'].key?('rights_statement_optional')

    profile_data['properties']['rights_statement_optional'] = build_rights_statement_optional(rs, optional_classes)
  end

  # rubocop:disable Metrics/MethodLength
  def build_rights_statement_optional(rs, available_classes)
    {
      'name' => 'rights_statement',
      'available_on' => { 'class' => available_classes },
      'cardinality' => { 'minimum' => 0 },
      'data_type' => rs['data_type'],
      'controlled_values' => rs['controlled_values']&.dup,
      'display_label' => { 'default' => find_i18n('Rights Statement') },
      'index_documentation' => rs['index_documentation'],
      'indexing' => rs['indexing']&.dup,
      'form' => { 'primary' => false, 'required' => false },
      'property_uri' => rs['property_uri'],
      'range' => rs['range'],
      'sample_values' => rs['sample_values']&.dup,
      'view' => rs['view']&.dup,
      'mappings' => rs['mappings']&.dup
    }.compact
  end
  # rubocop:enable Metrics/MethodLength

  def validate!
    validator = Hyrax::FlexibleSchemaValidatorService.new(profile: profile_data)
    validator.validate!
    return unless validator.errors.any?

    raise "M3 profile validation failed: #{validator.errors.join(', ')}"
  end

  def save
    validate!
    File.write(@output_path, profile_data.to_yaml)
    Rails.logger.debug "Migrated M3 profile saved to: #{@output_path}"
  end

  def find_i18n(label_value)
    I18n.reverse_lookup(label_value, scope: [:blacklight, :search, :fields, :show]) ||
      I18n.reverse_lookup(label_value, scope: [:blacklight, :search, :fields, :index]) ||
      label_value
  end

  def profile_editor
    @profile_editor ||= Hyrax::M3ProfileEditor.new(@source_path)
  end

  def profile_data
    @profile_data_override || profile_editor.profile_data
  end
end
