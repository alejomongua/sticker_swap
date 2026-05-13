class SwapOfferAcceptance
  class InvalidState < StandardError; end

  def initialize(swap_offer)
    @swap_offer = swap_offer
  end

  def call
    SwapOffer.transaction do
      swap_offer.lock!
      raise InvalidState, "La propuesta ya fue respondida." unless swap_offer.pending?

      inventory_items = locked_inventory_items
      swap_offer.offered_sticker_ids.each do |sticker_id|
        consume_required_item!(inventory_items, swap_offer.sender_id, sticker_id, "duplicate", "La persona que envió la propuesta ya no tiene una de las figuras ofrecidas.")
        consume_required_item!(inventory_items, swap_offer.receiver_id, sticker_id, "missing", "Ya no necesitas una de las figuras ofrecidas.")
      end
      swap_offer.requested_sticker_ids.each do |sticker_id|
        consume_required_item!(inventory_items, swap_offer.receiver_id, sticker_id, "duplicate", "Ya no tienes una de las figuras solicitadas.")
        consume_required_item!(inventory_items, swap_offer.sender_id, sticker_id, "missing", "La otra persona ya no necesita una de las figuras solicitadas.")
      end

      swap_offer.update!(status: :accepted, responded_at: Time.current)
    end
  end

  private
    attr_reader :swap_offer

    def locked_inventory_items
      sticker_ids = (swap_offer.offered_sticker_ids + swap_offer.requested_sticker_ids).uniq

      InventoryItem.lock.where(
        user_id: [ swap_offer.sender_id, swap_offer.receiver_id ],
        sticker_id: sticker_ids
      ).index_by { |item| [ item.user_id, item.sticker_id, item.status ] }
    end

    def consume_required_item!(inventory_items, user_id, sticker_id, status, error_message)
      item = inventory_items[[ user_id, sticker_id, status ]]
      raise InvalidState, error_message unless item

      item.consume_one!
    end
end
