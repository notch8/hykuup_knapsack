# frozen_string_literal: true

# OVERRIDE Hyrax 5.3.0: save the head_html content block for those allowed to update it
module Hyrax
  module ContentBlocksControllerHeadHtmlDecorator
    private

    def head_html_editor?
      can?(:update, ContentBlock.new(name: 'head_html'))
    end

    def update_value_from_params
      head_html = params.require(:content_block).permit(:head_html)[:head_html] if head_html_editor?
      head_html || super
    end
  end
end

Hyrax::ContentBlocksController.prepend Hyrax::ContentBlocksControllerHeadHtmlDecorator
Hyrax::ContentBlocksController.helper_method :head_html_editor?
