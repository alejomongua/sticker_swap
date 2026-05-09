class RegistrationsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 5, within: 10.minutes, only: :create, with: -> { redirect_to new_registration_path, alert: "Intenta de nuevo en unos minutos." }

  def new
    @user = User.new(receive_offer_notifications: true)
  end

  def create
    submission = registration_submission_params
    @user = User.new(submission.except(:invitation_code))

    unless StickerSwap::RuntimeConfig.valid_registration_code?(submission[:invitation_code])
      @user.errors.add(:base, "El código de invitación no es válido o ya fue usado.")
      render :new, status: :unprocessable_content
      return
    end

    @user.save!

    start_new_session_for(@user)
    redirect_to root_path, notice: "Tu cuenta se creó correctamente."
  rescue ActiveRecord::RecordInvalid
    render :new, status: :unprocessable_content
  end

  private
    def registration_submission_params
      params.require(:user).permit(
        :email,
        :username,
        :password,
        :password_confirmation,
        :receive_offer_notifications,
        :invitation_code
      )
    end
end
