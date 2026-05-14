class MatchmakingQuery
  Summary = Struct.new(:user, :can_offer, :can_request, keyword_init: true) do
    def direct_match?
      can_offer.any? && can_request.any?
    end
  end

  def initialize(user, group:)
    @group = group
    @user = user
  end

  def summaries
    other_users.filter_map do |other_user|
      summary_for(other_user)
    end.sort_by { |summary| [ summary.direct_match? ? 0 : 1, summary.user.username.downcase ] }
  end

  def summary_for_user(other_user)
    summary_for(other_user)
  end

  def summary_for_inventory(missing_stickers:, duplicate_stickers:, user: nil)
    summary_for_sticker_ids(
      other_missing_ids: missing_stickers.map(&:id),
      other_duplicate_ids: duplicate_stickers.map(&:id),
      user: user
    )
  end

  private
    attr_reader :group
    attr_reader :user

    def summary_for(other_user)
      other_missing_ids = []
      other_duplicate_ids = []

      other_user.inventory_items.each do |item|
        other_missing_ids << item.sticker_id if item.missing?
        other_duplicate_ids << item.sticker_id if item.duplicate?
      end

      summary_for_sticker_ids(
        other_missing_ids: other_missing_ids,
        other_duplicate_ids: other_duplicate_ids,
        user: other_user
      )
    end

    def summary_for_sticker_ids(other_missing_ids:, other_duplicate_ids:, user: nil)
      can_offer = current_duplicate_stickers.select { |sticker| other_missing_ids.include?(sticker.id) }
      can_request = current_missing_stickers.select { |sticker| other_duplicate_ids.include?(sticker.id) }

      return if can_offer.empty? && can_request.empty?

      Summary.new(user: user, can_offer: can_offer, can_request: can_request)
    end

    def current_duplicate_stickers
      @current_duplicate_stickers ||= user.duplicate_items.map(&:sticker).sort_by(&:sort_key)
    end

    def current_missing_stickers
      @current_missing_stickers ||= user.missing_items.map(&:sticker).sort_by(&:sort_key)
    end

    def other_users
      @other_users ||= begin
        return User.none if group.blank?

        group.users.where.not(id: user.id).includes(inventory_items: :sticker)
      end
    end
end
