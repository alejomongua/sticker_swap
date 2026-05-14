class ExternalInventoryMatchPreview
  Result = Struct.new(:can_offer, :can_request, :unknown_codes, :error_message, keyword_init: true) do
    def success?
      error_message.blank?
    end

    def direct_match?
      can_offer.any? && can_request.any?
    end

    def any_match?
      can_offer.any? || can_request.any?
    end
  end

  def initialize(user:, text:)
    @text = text
    @user = user
  end

  def call
    parsed_inventory = FiguritasAppInventoryParser.new(text: text).call
    return failure_result(parsed_inventory.error_message) unless parsed_inventory.success?

    summary = MatchmakingQuery.new(user, group: nil).summary_for_inventory(
      missing_stickers: parsed_inventory.missing_stickers,
      duplicate_stickers: parsed_inventory.duplicate_stickers
    )

    Result.new(
      can_offer: summary&.can_offer || [],
      can_request: summary&.can_request || [],
      unknown_codes: parsed_inventory.unknown_codes,
      error_message: nil
    )
  end

  private
    attr_reader :text, :user

    def failure_result(message)
      Result.new(can_offer: [], can_request: [], unknown_codes: [], error_message: message)
    end
end