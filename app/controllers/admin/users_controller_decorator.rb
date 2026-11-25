# frozen_string_literal: true

# OVERRIDE Hyku v7.1.0 Admin::UsersController#activate: only acts on a pending user of this repository gives them a random password, and emails a set-password link.
#   Remove once Hyku is bumped past this fix; see notch8/notch8-ops#848.
module Admin
  module UsersControllerDecorator
    def activate
      user = User.for_repository.find(params[:id])
      activated = false
      user.with_lock do
        if user.invited_to_sign_up?
          super
          activated = user.reload.invitation_accepted?
        else
          redirect_to hyrax.admin_users_path, flash: { error: t('hyrax.admin.users.activate.failure', user:) }
        end
      end
      return unless activated

      # Hyku's activate assigns HYKU_USER_DEFAULT_PASSWORD when set; replace it with a random one
      user.update!(password: Devise.friendly_token[0, 20])
      send_activation_instructions(user)
    end

    private

    def send_activation_instructions(user)
      token = user.send(:set_reset_password_token)
      user.send(:send_devise_notification, :reset_password_instructions, token,
                template_name: 'activation_instructions',
                subject: t('hyrax.admin.users.activate.email_subject'))
    end
  end
end

Admin::UsersController.prepend(Admin::UsersControllerDecorator)
