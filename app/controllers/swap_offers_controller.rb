class SwapOffersController < ApplicationController
  before_action :require_current_group!

  def index
    @received_offers = current_group.swap_offers.where(receiver: current_user).includes(:sender, :offered_sticker, :requested_sticker).latest_first
    @sent_offers = current_group.swap_offers.where(sender: current_user).includes(:receiver, :offered_sticker, :requested_sticker).latest_first
  end

  def create
    @swap_offer = current_user.sent_swap_offers.new(create_params.merge(group: current_group, status: :pending))

    if @swap_offer.save
      redirect_to matches_path, notice: "La propuesta se envió correctamente."
    else
      redirect_to matches_path, alert: @swap_offer.errors.full_messages.to_sentence
    end
  end

  def accept
    offer = current_group.swap_offers.where(receiver: current_user).find(params[:id])
    offer.accept!
    redirect_to swap_offers_path, notice: "El intercambio fue aceptado y el inventario se actualizó."
  rescue SwapOfferAcceptance::InvalidState => error
    redirect_to swap_offers_path, alert: error.message
  end

  def decline
    offer = current_group.swap_offers.where(receiver: current_user).find(params[:id])
    offer.decline!
    redirect_to swap_offers_path, notice: "La propuesta fue rechazada."
  rescue SwapOfferAcceptance::InvalidState => error
    redirect_to swap_offers_path, alert: error.message
  end

  private
    def create_params
      params.require(:swap_offer).permit(:receiver_id, :offered_sticker_id, :requested_sticker_id)
    end
end
