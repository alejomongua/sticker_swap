class PasswordsController < ApplicationController
  allow_unauthenticated_access
  before_action :set_user_by_token, only: %i[ edit update ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_password_path, alert: "Intenta de nuevo en unos minutos." }

  def new
  end

  def create
    if user = User.find_by(email: params[:email].to_s.strip.downcase)
      PasswordsMailer.reset(user).deliver_later
    end

    redirect_to new_session_path, notice: "Si existe una cuenta con ese correo, enviamos las instrucciones de recuperación."
  end

  def edit
  end

  def update
    if @user.update(password_params)
      @user.sessions.destroy_all
      redirect_to new_session_path, notice: "Tu contraseña se actualizó correctamente."
    else
      flash.now[:alert] = @user.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_content
    end
  end

  private
    def password_params
      params.permit(:password, :password_confirmation)
    end

    def set_user_by_token
      @user = User.find_by_password_reset_token!(params[:token])
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      redirect_to new_password_path, alert: "El enlace para recuperar acceso no es válido o ya venció."
    end
end
