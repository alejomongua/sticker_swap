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
      consume_required_item!(inventory_items, swap_offer.sender_id, swap_offer.offered_sticker_id, "duplicate", "La persona que envió la propuesta ya no tiene esa repetida.")
      consume_required_item!(inventory_items, swap_offer.receiver_id, swap_offer.offered_sticker_id, "missing", "Ya no necesitas la figura ofrecida.")
      consume_required_item!(inventory_items, swap_offer.receiver_id, swap_offer.requested_sticker_id, "duplicate", "Ya no tienes la repetida solicitada.")
      consume_required_item!(inventory_items, swap_offer.sender_id, swap_offer.requested_sticker_id, "missing", "La otra persona ya no necesita la figura solicitada.")

      swap_offer.update!(status: :accepted, responded_at: Time.current)
    end
  end

  private
    attr_reader :swap_offer

    def locked_inventory_items
      InventoryItem.lock.where(
        user_id: [ swap_offer.sender_id, swap_offer.receiver_id ],
        sticker_id: [ swap_offer.offered_sticker_id, swap_offer.requested_sticker_id ]
      ).index_by { |item| [ item.user_id, item.sticker_id, item.status ] }
    end

    def consume_required_item!(inventory_items, user_id, sticker_id, status, error_message)
      item = inventory_items[[ user_id, sticker_id, status ]]
      raise InvalidState, error_message unless item

      item.consume_one!
    end
end
