class ProfilesController < ApplicationController
  def edit
    @user = current_user
  end

  def update
    @user = current_user
    attributes = profile_params
    password_changed = attributes[:password].present?

    unless password_changed
      attributes = attributes.except(:password, :password_confirmation)
    end

    if password_changed && !current_user.authenticate(params.dig(:user, :current_password))
      @user.assign_attributes(attributes.except(:password, :password_confirmation))
      @user.errors.add(:current_password, "no coincide con tu contraseña actual")
      render :edit, status: :unprocessable_content
      return
    end

    if @user.update(attributes)
      @user.sessions.where.not(id: Current.session.id).destroy_all if password_changed
      redirect_to edit_profile_path, notice: "Tu perfil se actualizó correctamente."
    else
      render :edit, status: :unprocessable_content
    end
  end

  private
    def profile_params
      params.require(:user).permit(:email, :username, :password, :password_confirmation)
    end
end
