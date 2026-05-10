class GroupMembershipsController < ApplicationController
  before_action :set_group
  before_action :require_group_admin!

  def destroy
    membership = @group.group_memberships.includes(:user).find(params[:id])
    username = membership.user.username

    if membership.destroy
      redirect_to groups_path, notice: "#{username} salió del grupo."
    else
      redirect_to groups_path, alert: membership.errors.full_messages.to_sentence
    end
  end

  private
    def set_group
      @group = current_user.groups.find(params[:group_id])
    end

    def require_group_admin!
      return if current_user.admin_of?(@group)

      redirect_to groups_path, alert: "Solo el administrador puede gestionar este grupo."
    end
end
