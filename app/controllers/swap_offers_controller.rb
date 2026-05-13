class SwapOffersController < ApplicationController
  before_action :require_current_group!

  def index
    @received_offers = current_group.swap_offers.where(receiver: current_user).includes(:sender, :countered_from).latest_first
    @sent_offers = current_group.swap_offers.where(sender: current_user).includes(:receiver, :countered_from).latest_first
    @counter_summaries = build_counter_summaries
  end

  def create
    @swap_offer = build_swap_offer

    created = false

    SwapOffer.transaction do
      created = @swap_offer.save
      raise ActiveRecord::Rollback unless created

      @swap_offer.countered_from&.counter!
    end

    if created && @swap_offer.persisted?
      redirect_to create_success_path, notice: success_message
    else
      redirect_to create_failure_path, alert: @swap_offer.errors.full_messages.to_sentence
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to create_failure_path, alert: "La propuesta que intentas modificar ya no está disponible."
  rescue SwapOfferAcceptance::InvalidState => error
    redirect_to create_failure_path, alert: error.message
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
      params.require(:swap_offer).permit(:countered_from_id, :offered_codes_text, :receiver_id, :requested_codes_text)
    end

    def build_swap_offer
      counter_source = counter_source_offer

      current_user.sent_swap_offers.new(
        group: current_group,
        receiver: counter_source&.sender || User.find(create_params[:receiver_id]),
        status: :pending,
        countered_from: counter_source
      ).tap do |offer|
        offer.offered_codes_text = create_params[:offered_codes_text]
        offer.requested_codes_text = create_params[:requested_codes_text]
      end
    end

    def counter_source_offer
      return if create_params[:countered_from_id].blank?

      @counter_source_offer ||= current_group.swap_offers.pending.where(receiver: current_user).find(create_params[:countered_from_id])
    end

    def build_counter_summaries
      matchmaking_query = MatchmakingQuery.new(current_user, group: current_group)

      @received_offers.each_with_object({}) do |offer, summaries|
        next unless offer.pending?

        summaries[offer.id] = matchmaking_query.summary_for_user(offer.sender)
      end
    end

    def success_message
      create_params[:countered_from_id].present? ? "La contraoferta se envió correctamente." : "La propuesta se envió correctamente."
    end

    def create_success_path
      create_params[:countered_from_id].present? ? swap_offers_path : matches_path
    end

    def create_failure_path
      create_params[:countered_from_id].present? ? swap_offers_path : matches_path
    end
end
