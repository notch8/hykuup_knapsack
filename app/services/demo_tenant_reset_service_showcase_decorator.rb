# frozen_string_literal: true

# OVERRIDE Hyku v7.1.0 - let HykuUP's showcase tenants reset on demand.
#
# Hyku resets only accounts flagged public_demo_tenant, a flag that also
# publishes the admin login and marks the site noindex, so the curated showcase
# tenants stay unflagged and are named here instead. Every other unflagged
# tenant is still refused: a reset wipes all of its works.
module DemoTenantResetServiceShowcaseDecorator
  SHOWCASE_TENANTS = %w[ellison harborview meridian].freeze
  SHOWCASE_SUPERADMINS = %w[nick@notch8.com].freeze

  private

  def guard_demo_tenant!
    return if showcase_tenant?

    super
  end

  def revoke_visitor_access!
    super
    grant_showcase_superadmins! if showcase_tenant?
  end

  def showcase_tenant?
    SHOWCASE_TENANTS.include?(account&.name)
  end

  def grant_showcase_superadmins!
    SHOWCASE_SUPERADMINS.each do |email|
      user = User.find_by(email:)
      next log("#{email} has no account here; not granted superadmin", level: :warn) unless user

      user.add_role(:superadmin, Site.instance)
      log "granted superadmin to #{email}"
    end
  end
end

DemoTenantResetService.prepend(DemoTenantResetServiceShowcaseDecorator)
