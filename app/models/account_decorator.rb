# frozen_string_literal: true

# OVERRIDE Hyku v6.2.0: Add consortium membership functionality for tenant-specific configuration
module AccountDecorator
  extend ActiveSupport::Concern

  included do
    before_validation :normalize_part_of_consortia
    validates :part_of_consortia, inclusion: { in: Consortium.identifiers, allow_nil: true }
  end

  # Checks if the account is part of a specific consortium.
  # @param consortium_name [String] The identifier of the consortium to check.
  # @return [Boolean] true if the account is part of the specified consortium.
  def part_of_consortium?(consortium_name)
    part_of_consortia == consortium_name
  end

  # Returns the identifier of the consortium this account belongs to.
  # @return [String, nil] The consortium identifier (e.g., "mobius") or nil.
  def consortium
    part_of_consortia
  end

  private

  # A `before_validation` callback that converts a blank `part_of_consortia`
  # value to `nil`. This allows the "None" option (which submits an empty string)
  # to pass the `allow_nil: true` validation.
  # @return [void]
  def normalize_part_of_consortia
    self.part_of_consortia = nil if part_of_consortia.blank?
  end
end

Account.include(AccountDecorator)
