# frozen_string_literal: true

# Represents a consortium of tenants, loaded from a YAML configuration file.
# This class provides an interface for accessing consortium data without
# requiring a database table.
class Consortium
  attr_reader :name, :identifier

  # Initializes a new Consortium object.
  # @param name [String] The display name of the consortium (e.g., "Mobius Consortium").
  # @param identifier [String] The unique identifier for the consortium (e.g., "mobius").
  def initialize(name:, identifier:)
    @name = name
    @identifier = identifier
  end

  class << self
    # Loads all consortiums from the YAML configuration file.
    # @return [Array<Consortium>] An array of Consortium objects.
    def all
      @all ||= consortia_config.map do |config|
        new(name: config['name'], identifier: config['identifier'])
      end
    end

    # Provides an array of options suitable for a form dropdown.
    # Includes a "None" option.
    # @return [Array<Array<String, String, nil>>]
    def options_for_select
      [['None', nil]] + all.map { |c| [c.name, c.identifier] }
    end

    # Returns a simple array of all valid consortium identifiers.
    # Useful for validations.
    # @return [Array<String>]
    def identifiers
      all.map(&:identifier)
    end

    private

    # Loads and parses the YAML file.
    # Caches the result to avoid repeated file reads.
    # @return [Array<Hash>]
    def consortia_config
      @consortia_config ||=
        begin
          YAML.load_file(HykuKnapsack::Engine.root.join('config', 'consortia.yml'))
        rescue Errno::ENOENT
          Rails.logger.warn "Consortia config file not found at config/consortia.yml. Returning empty array."
          []
        end
    end
  end
end
