class GroupsController < ApplicationController
  before_action :set_group, only: %i[ update activate regenerate_invitation_code ]
  before_action :require_group_admin!, only: %i[ update regenerate_invitation_code ]

  def index
    prepare_index_state
  end

  def create
    @new_group = Group.new(group_params.merge(admin_user: current_user))

    if @new_group.save
      current_user.update!(active_group: @new_group)
      Current.group = @new_group
      redirect_to groups_path, notice: "El grupo se creó correctamente."
    else
      flash.now[:alert] = @new_group.errors.full_messages.to_sentence
      prepare_index_state
      render :index, status: :unprocessable_content
    end
  end

  def join
    group = Group.find_by_invitation_code(join_params[:invitation_code])
    return render_join_error("El código de invitación no es válido.") if group.blank?

    if current_user.member_of?(group)
      current_user.update!(active_group: group)
      Current.group = group
      redirect_to groups_path, notice: "Cambiaste al grupo #{group.name}."
      return
    end

    return render_join_error("Este grupo tiene el registro desactivado.") unless group.registration_open?

    group.add_member!(current_user)
    Current.group = group
    redirect_to groups_path, notice: "Ahora haces parte de #{group.name}."
  rescue ActiveRecord::RecordInvalid => error
    render_join_error(error.record.errors.full_messages.to_sentence.presence || "No fue posible unirte al grupo.")
  end

  def update
    if @group.update(update_params)
      redirect_to groups_path, notice: "La configuración del grupo se actualizó."
    else
      flash.now[:alert] = @group.errors.full_messages.to_sentence
      prepare_index_state
      render :index, status: :unprocessable_content
    end
  end

  def activate
    current_user.update!(active_group: @group)
    Current.group = @group
    redirect_back fallback_location: groups_path, notice: "Ahora estás trabajando en #{@group.name}."
  end

  def regenerate_invitation_code
    @group.regenerate_invitation_code!
    redirect_to groups_path, notice: "Se generó un nuevo código de invitación."
  end

  private
    def prepare_index_state
      @groups = current_user.groups.includes(:admin_user).order(:name).to_a
      @new_group ||= Group.new
      @managed_group = current_group if current_group_admin?
      @managed_memberships = if @managed_group.present?
        @managed_group.group_memberships.includes(:user).to_a.sort_by do |membership|
          [ membership.user_id == @managed_group.admin_user_id ? 0 : 1, membership.user.username.downcase ]
        end
      else
        []
      end
    end

    def render_join_error(message)
      flash.now[:alert] = message
      prepare_index_state
      render :index, status: :unprocessable_content
    end

    def set_group
      @group = current_user.groups.find(params[:id])
    end

    def require_group_admin!
      return if current_user.admin_of?(@group)

      redirect_to groups_path, alert: "Solo el administrador puede gestionar este grupo."
    end

    def group_params
      params.require(:group).permit(:name)
    end

    def join_params
      params.require(:group).permit(:invitation_code)
    end

    def update_params
      params.require(:group).permit(:registration_open)
    end
end
