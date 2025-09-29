# frozen_string_literal: true

# OVERRIDE Hyku v6.2.0: Add consortium membership functionality for tenant-specific configuration
module AccountDecorator
  extend ActiveSupport::Concern

  # Available consortium options for dropdown
  CONSORTIUM_OPTIONS = [
    ['None', nil],
    ['UNCA Consortium', 'unca'],
    ['Mobius Consortium', 'mobius']
  ].freeze

  included do
    validates :part_of_consortia, inclusion: { in: CONSORTIUM_OPTIONS.map(&:last), allow_nil: true }
  end

  # Check if account is part of a specific consortium
  # @param consortium_name [String] The consortium to check membership for
  # @return [Boolean] true if account is part of the specified consortium
  def part_of_consortium?(consortium_name)
    part_of_consortia == consortium_name
  end

  # Get consortium-specific configuration
  # @return [String, nil] The consortium this account belongs to
  def consortium
    part_of_consortia
  end
end

Account.include(AccountDecorator)
