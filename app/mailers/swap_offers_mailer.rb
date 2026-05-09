class SwapOffersMailer < ApplicationMailer
  def created(swap_offer)
    @swap_offer = swap_offer
    @receiver = swap_offer.receiver
    @sender = swap_offer.sender

    mail subject: "Nueva propuesta de intercambio en StickerSwap", to: @receiver.email
  end
end
