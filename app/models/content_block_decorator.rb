# frozen_string_literal: true

# OVERRIDE Hyku v7.1.0: add the head_html content block, markup a superadmin sets for public page heads
module ContentBlockDecorator
  def head_html
    find_or_create_by(name: 'head_html')
  end
end

ContentBlock.singleton_class.prepend(ContentBlockDecorator)
