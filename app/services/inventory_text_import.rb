class InventoryTextImport
  Result = Struct.new(
    :missing_count,
    :duplicate_copies_count,
    :duplicate_items_count,
    :unknown_codes,
    :error_message,
    keyword_init: true
  ) do
    def success?
      error_message.blank?
    end
  end

  def initialize(user:, text:)
    @text = text
    @user = user
  end

  def call
    parsed_inventory = FiguritasAppInventoryParser.new(text: text).call
    return failed_result(parsed_inventory.error_message) unless parsed_inventory.success?

    InventoryItem.transaction do
      user.inventory_items.delete_all

      create_missing_items!(parsed_inventory.missing_stickers)
      create_duplicate_items!(parsed_inventory.duplicate_sticker_counts)
    end

    Result.new(
      missing_count: parsed_inventory.missing_count,
      duplicate_copies_count: parsed_inventory.duplicate_copies_count,
      duplicate_items_count: parsed_inventory.duplicate_items_count,
      unknown_codes: parsed_inventory.unknown_codes,
      error_message: nil
    )
  rescue ActiveRecord::RecordInvalid => error
    Result.new(missing_count: 0, duplicate_copies_count: 0, duplicate_items_count: 0, unknown_codes: [], error_message: error.record.errors.full_messages.to_sentence)
  end

  private
    attr_reader :text, :user

    def failed_result(message)
      Result.new(
        missing_count: 0,
        duplicate_copies_count: 0,
        duplicate_items_count: 0,
        unknown_codes: [],
        error_message: message
      )
    end

    def create_missing_items!(missing_stickers)
      missing_stickers.each do |sticker|
        user.inventory_items.create!(sticker: sticker, status: :missing)
      end
    end

    def create_duplicate_items!(duplicate_sticker_counts)
      duplicate_sticker_counts.each do |sticker, quantity|
        user.inventory_items.create!(sticker: sticker, status: :duplicate, quantity: quantity)
      end
    end
end