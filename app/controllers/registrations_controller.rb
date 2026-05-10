class RegistrationsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 5, within: 10.minutes, only: :create, with: -> { redirect_to new_registration_path, alert: "Intenta de nuevo en unos minutos." }

  def new
    @user = User.new(receive_offer_notifications: false)
    @registration_mode = "join_group"
  end

  def create
    submission = registration_submission_params
    @registration_mode = normalized_registration_mode(submission[:registration_mode])
    @user = User.new(submission.slice(:email, :username, :password, :password_confirmation)
                               .merge(receive_offer_notifications: false))

    User.transaction do
      if @registration_mode == "create_group"
        create_group_for_registration!(submission)
      else
        join_group_for_registration!(submission)
      end
    end

    start_new_session_for(@user.reload)
    redirect_to root_path, notice: "Tu cuenta se creó correctamente."
  rescue ActiveRecord::RecordInvalid
    render :new, status: :unprocessable_content
  end

  private
    def create_group_for_registration!(submission)
      group_name = submission[:group_name].to_s.strip
      return invalid_registration!("Debes escribir un nombre para tu grupo.") if group_name.blank?

      @user.save!
      group = Group.create!(name: group_name, admin_user: @user)
      @user.update!(active_group: group)
    end

    def join_group_for_registration!(submission)
      group = Group.find_by_invitation_code(submission[:invitation_code])
      return invalid_registration!("El código de invitación no es válido.") if group.blank?
      return invalid_registration!("Este grupo tiene el registro desactivado.") unless group.registration_open?

      @user.save!
      group.add_member!(@user)
    end

    def invalid_registration!(message)
      @user.errors.add(:base, message)
      raise ActiveRecord::RecordInvalid, @user
    end

    def normalized_registration_mode(raw_mode)
      raw_mode.to_s == "create_group" ? "create_group" : "join_group"
    end

    def registration_submission_params
      params.require(:user).permit(
        :email,
        :group_name,
        :registration_mode,
        :invitation_code,
        :username,
        :password,
        :password_confirmation
      )
    end
end
