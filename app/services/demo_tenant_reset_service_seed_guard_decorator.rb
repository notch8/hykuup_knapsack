# frozen_string_literal: true

# OVERRIDE Hyku - refuse the reset before destroying anything when the seed
# payload is missing.
#
# `reset!` guards the snapshot before the wipe but only reaches `import_seed!`
# after it, so a missing DEMO_SEED_CSV_PATH payload empties the tenant and then
# raises. The payload lives on a shared volume outside version control, so its
# absence is a real state, not a theoretical one.
module DemoTenantResetServiceSeedGuardDecorator
  private

  # `wipe_content!` is the first destructive step in `reset!`, so guarding here
  # covers every caller without restating the method.
  def wipe_content!
    if seed_csv_path.present? && !File.exist?(seed_csv_path)
      raise DemoTenantResetService::ImportFailed,
            "seed csv not found at #{seed_csv_path}; refusing to wipe #{account.cname}"
    end

    super
  end
end

DemoTenantResetService.prepend(DemoTenantResetServiceSeedGuardDecorator)
