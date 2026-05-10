module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :require_authentication
    helper_method :authenticated?, :current_group, :current_user
  end

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
    end
  end

  private
    def authenticated?
      resume_session
    end

    def current_user
      Current.user
    end

    def current_group
      Current.group ||= begin
        user = current_user
        if user.present?
          user.active_group || user.groups.order("group_memberships.created_at ASC", "group_memberships.id ASC").first.tap do |group|
            user.update_column(:active_group_id, group.id) if group.present? && user.active_group_id != group.id
          end
        end
      end
    end

    def require_authentication
      resume_session || request_authentication
    end

    def resume_session
      Current.session ||= find_session_by_cookie
    end

    def find_session_by_cookie
      Session.find_by(id: cookies.signed[:session_id]) if cookies.signed[:session_id]
    end

    def request_authentication
      session[:return_to_after_authenticating] = request.fullpath
      redirect_to new_session_path, alert: "Debes iniciar sesión para continuar."
    end

    def after_authentication_url
      session.delete(:return_to_after_authenticating) || root_path
    end

    def start_new_session_for(user)
      user.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip).tap do |session_record|
        Current.session = session_record
        Current.group = user.active_group
        cookies.signed.permanent[:session_id] = {
          value: session_record.id,
          httponly: true,
          same_site: :lax,
          secure: Rails.env.production?
        }
      end
    end

    def terminate_session
      Current.session&.destroy
      Current.group = nil
      Current.session = nil
      cookies.delete(:session_id)
    end
end
