# frozen_string_literal: true

module HykuKnapsack
  # Routes exist for every registered curation concern, and only the picker filters by
  # what the tenant offers. See notch8/hykuup_knapsack#707.
  module WorkTypeGuardDecorator
    def new
      work_type_offerable? ? super : reject_unoffered_work_type
    end

    def create
      work_type_offerable? ? super : reject_unoffered_work_type
    end

    private

    def work_type_offerable?
      TenantWorkTypeFilter.offerable_work_types.include?(guarded_work_type_name)
    end

    # Profiles and curation_concern_type suffix stock types but not custom ones
    # (OerResource, MobiusWork). Strip, or no stock type matches available_works.
    def guarded_work_type_name
      self.class.curation_concern_type.to_s.demodulize.sub(/Resource\z/, '')
    end

    def reject_unoffered_work_type
      redirect_to main_app.root_path,
                  alert: I18n.t('hyku_knapsack.works.errors.work_type_not_offered')
    end
  end
end

# Not a before_action on Hyku::WorksControllerBehavior: that concern is already included
# by the time this file loads, so it would never reach these controllers.
Hyrax.config.registered_curation_concern_types.each do |work_type|
  "Hyrax::#{work_type.pluralize}Controller".safe_constantize
                                           &.prepend(HykuKnapsack::WorkTypeGuardDecorator)
end
