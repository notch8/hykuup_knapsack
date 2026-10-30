# frozen_string_literal: true

# OVERRIDE Hyku v7.1.0 - wait only for the import itself before restoring a
# demo tenant.
#
# Hyku also waits on derivatives and gives up after an hour, which a long or hung
# video transcode exceeds; the restore steps only need the works and collections.
# Remove once Hyku includes samvera/hyku#3486.
module DemoTenantResetServiceImportDrainDecorator
  private

  def unfinished_jobs_for_tenant
    super.where('job_class LIKE ?', 'Bulkrax::%')
  end
end

DemoTenantResetService.prepend(DemoTenantResetServiceImportDrainDecorator)
