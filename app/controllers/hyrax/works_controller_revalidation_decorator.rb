# frozen_string_literal: true

# OVERRIDE Hyku v7.1.0 so a browser revalidating a work or its manifest gets a 304, not a 500.
# Remove once Hyku includes samvera/hyku#3409.
module Hyrax
  module WorksControllerRevalidationDecorator
    # Hyku's show and manifest call fresh_when, which has already answered 304 when the
    # browser's copy is current, and then super, where Hyrax renders again.
    def show
      super unless performed?
    end

    def manifest
      super unless performed?
    end
  end
end

# Hyku defines show and manifest on each controller, so a prepend here lands between them and Hyrax.
Hyku::WorksControllerBehavior.prepend(Hyrax::WorksControllerRevalidationDecorator)
