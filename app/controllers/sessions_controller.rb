class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_path, alert: "Intenta de nuevo en unos minutos." }

  def new
  end

  def create
    credentials = params.permit(:email, :password)

    if user = User.authenticate_by(email: credentials[:email].to_s.strip.downcase, password: credentials[:password])
      start_new_session_for user
      redirect_to after_authentication_url, notice: "Sesión iniciada correctamente.", status: :see_other
    else
      flash.now[:alert] = "Revisa el correo y la contraseña."
      render :new, status: :unprocessable_content
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path, notice: "Sesión cerrada.", status: :see_other
  end
end
