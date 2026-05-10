class Current < ActiveSupport::CurrentAttributes
  attribute :group, :session
  delegate :user, to: :session, allow_nil: true
end
