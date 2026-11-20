# frozen_string_literal: true

module Proprietor
  # Lets the showcase operators save the look of, and reset, the HykuUP showcase tenants.
  class ShowcasesController < ProprietorController
    before_action do
      authorize! :manage, Account
      raise CanCan::AccessDenied unless ShowcaseTenant.operator?(current_user)
    end
    before_action :load_showcase, except: :index

    def index
      add_breadcrumb t(:'hyrax.controls.home'), root_path
      add_breadcrumb t('.header'), proprietor_showcases_path
      @showcases = ShowcaseTenant.all
    end

    def snapshot
      return back(error: t('.restoring', name: @showcase.name)) if @showcase.restoring_thumbnails?

      enqueue(ShowcaseSnapshotJob, t('.queued', name: @showcase.name))
    end

    def reset
      return back(error: t('.mistyped', name: @showcase.name)) unless params[:confirm] == @showcase.name
      return back(error: t('.no_snapshot', name: @showcase.name)) unless @showcase.look_saved_at

      enqueue(ShowcaseResetJob, t('.queued', name: @showcase.name))
    end

    private

    def load_showcase
      @showcase = ShowcaseTenant.find(params[:id])
    end

    def enqueue(job, notice)
      return back(error: t('proprietor.showcases.busy', name: @showcase.name)) if @showcase.saving_or_resetting?

      Apartment::Tenant.switch(@showcase.tenant) { job.perform_later }
      back(notice:)
    end

    def back(flash)
      redirect_to proprietor_showcases_path, flash:
    end
  end
end
