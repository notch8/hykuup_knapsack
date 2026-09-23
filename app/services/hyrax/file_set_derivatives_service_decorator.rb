# frozen_string_literal: true

# OVERRIDE Hyrax v5.0.0 because some of MOBIUS's PDFs were throwing errors
module Hyrax
  module FileSetDerivativesServiceDecorator
    def create_pdf_derivatives(filename)
      super
    rescue RuntimeError => e
      Rails.logger.error("Error creating PDF derivatives for #{filename}: #{e.message}")
    end
  end
end

Hyrax::FileSetDerivativesService.prepend(Hyrax::FileSetDerivativesServiceDecorator)
