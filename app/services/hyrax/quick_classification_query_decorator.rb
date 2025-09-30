# frozen_string_literal: true

# OVERRIDE Hyku v6.2.0: Apply tenant-specific work type filtering to work creation
module Hyrax
  module QuickClassificationQueryDecorator
    extend ActiveSupport::Concern

    # OVERRIDE: Apply tenant-specific filtering to work types available for creation
    # @return [Array<Class>] Array of work type classes that are authorized for the current tenant
    def authorized_models
      super.select { |model| Site.instance.available_works.include?(model.name) }
    end

    # OVERRIDE: Check if all tenant-allowed work types are available
    # @return [Boolean] true if all tenant-allowed work types are available
    def all?
      # Compare against the tenant's available works, not all registered types
      models.map(&:to_s).sort == Site.instance.available_works.sort
    end
  end
end

Hyrax::QuickClassificationQuery.prepend(Hyrax::QuickClassificationQueryDecorator)
