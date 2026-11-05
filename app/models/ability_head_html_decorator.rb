# frozen_string_literal: true

# OVERRIDE Hyku a6eed62d: only tenant superadmins, which rolify extends to global superadmins, update the head_html content block
module AbilityHeadHtmlDecorator
  def head_html_permissions
    return if tenant_superadmin?

    cannot :update, ContentBlock, name: 'head_html'
  end
end

Ability.prepend(AbilityHeadHtmlDecorator)
Ability.ability_logic += [:head_html_permissions] unless Ability.ability_logic.include?(:head_html_permissions)
