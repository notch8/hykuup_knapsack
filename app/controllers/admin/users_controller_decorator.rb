# frozen_string_literal: true

# OVERRIDE Hyku v7.1.0 Admin::UsersController#activate: only acts on a pending user of this repository, gives them a random password, and emails a set-password link.
#   Remove once Hyku is bumped past this fix; see notch8/notch8-ops#848.
module Admin
  module UsersControllerDecorator
    def activate
      user = User.for_repository.find(params[:id])

      if activate_with_email(user)
        redirect_to hyrax.admin_users_path, notice: t('hyrax.admin.users.activate.success', user:)
      else
        redirect_to hyrax.admin_users_path, flash: { error: t('hyrax.admin.users.activate.failure', user:) }
      end
    end

    private

    def activate_with_email(user)
      user.with_lock do
        next false unless user.invited_to_sign_up?

        user.password = Devise.friendly_token[0, 20]
        next false unless user.save && user.accept_invitation!

        send_activation_instructions(user)
        true
      rescue StandardError => e
        # Rolls back the activation so a failed email leaves the user pending, not locked out
        Rails.logger.error("Activation email failed for user #{user.id}: #{e.class}: #{e.message}")
        raise ActiveRecord::Rollback
      end
    end

    def send_activation_instructions(user)
      token = user.send(:set_reset_password_token)
      user.send(:send_devise_notification, :reset_password_instructions, token,
                template_name: 'activation_instructions',
                subject: t('hyrax.admin.users.activate.email_subject'))
    end
  end
end

Admin::UsersController.prepend(Admin::UsersControllerDecorator)
