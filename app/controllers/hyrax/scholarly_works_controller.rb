# frozen_string_literal: true

# Generated via
#  `rails generate hyrax:work_resource ScholarlyWork`
module Hyrax
  # Generated controller for ScholarlyWork
  class ScholarlyWorksController < ApplicationController
    # Adds Hyrax behaviors to the controller.
    include Hyrax::WorksControllerBehavior
    include Hyku::WorksControllerBehavior
    include Hyrax::BreadcrumbsForWorks
    # Prepended here, not only by WorkTypeGuardDecorator's loop: this controller is
    # reloadable, so a reload drops a prepend applied from outside the class body.
    prepend HykuKnapsack::WorkTypeGuardDecorator
    self.curation_concern_type = ::ScholarlyWork

    # Use a Valkyrie aware form service to generate Valkyrie::ChangeSet style
    # forms.
    self.work_form_service = Hyrax::FormFactory.new
  end
end
