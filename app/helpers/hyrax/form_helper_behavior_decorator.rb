# frozen_string_literal: true

# OVERRIDE Hyku 7.1: a mesh-sourced property raised NotImplementedError from
# Qa::Authorities::Mesh#all and 500ed the work form; returning nil lets the helper
# offer it as autocomplete. Drop once the Hyku pin includes samvera/hyku#3371.
module Hyrax
  module FormHelperBehaviorDecorator
    private

    def local_vocabulary_options_for(source)
      super
    rescue NotImplementedError => e
      Rails.logger.warn "Failed to load controlled vocabulary for #{source}: #{e.message}"
      nil
    end
  end
end

Hyrax::FormHelperBehavior.prepend(Hyrax::FormHelperBehaviorDecorator)
