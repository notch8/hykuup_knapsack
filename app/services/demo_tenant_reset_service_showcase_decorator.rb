# frozen_string_literal: true

# OVERRIDE Hyku v7.1.0 - let HykuUP's showcase tenants reset on demand.
#
# Hyku resets only accounts flagged public_demo_tenant, a flag that also
# publishes the admin login and marks the site noindex, so the curated showcase
# tenants stay unflagged and are named here instead. Every other unflagged
# tenant is still refused: a reset wipes all of its works.
module DemoTenantResetServiceShowcaseDecorator
  SHOWCASE_TENANTS = %w[ellison harborview meridian].freeze

  private

  def guard_demo_tenant!
    return if SHOWCASE_TENANTS.include?(account&.name)

    super
  end
end

DemoTenantResetService.prepend(DemoTenantResetServiceShowcaseDecorator)
