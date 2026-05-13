class InventoryBulkConsume
  Result = Struct.new(:processed_count, :unknown_codes, :unavailable_codes, :insufficient_codes, :error_message, keyword_init: true) do
    def success?
      error_message.blank?
    end
  end

  def initialize(user:, status:, codes:)
    @codes = codes
    @status = status
    @user = user
  end

  def call
    return Result.new(processed_count: 0, unknown_codes: [], unavailable_codes: [], insufficient_codes: [], error_message: "Debes ingresar al menos una figura.") if parsed_code_counts.empty?
    return Result.new(processed_count: 0, unknown_codes: [], unavailable_codes: [], insufficient_codes: [], error_message: "El estado del inventario no es válido.") unless InventoryItem.statuses.key?(status)

    stickers_by_code = parsed_code_counts.keys.index_with { |code| Sticker.find_by_code(code) }
    unknown_codes = stickers_by_code.select { |_code, sticker| sticker.nil? }.keys
    unavailable_codes = []
    insufficient_codes = []
    processed_count = 0

    InventoryItem.transaction do
      stickers_by_code.each do |code, sticker|
        next if sticker.nil?

        inventory_item = user.inventory_items.find_by(sticker: sticker, status: status)
        unless inventory_item
          unavailable_codes << code
          next
        end

        consume_item!(inventory_item, code:, occurrences: parsed_code_counts.fetch(code), insufficient_codes:)
        processed_count += 1
      end
    end

    Result.new(
      processed_count: processed_count,
      unknown_codes: unknown_codes,
      unavailable_codes: unavailable_codes,
      insufficient_codes: insufficient_codes,
      error_message: nil
    )
  rescue ActiveRecord::RecordInvalid => error
    Result.new(processed_count: 0, unknown_codes: [], unavailable_codes: [], insufficient_codes: [], error_message: error.record.errors.full_messages.to_sentence)
  end

  private
    attr_reader :codes, :status, :user

    def duplicate?
      status == "duplicate"
    end

    def consume_item!(inventory_item, code:, occurrences:, insufficient_codes:)
      return inventory_item.destroy! unless duplicate?

      if occurrences >= inventory_item.quantity
        insufficient_codes << code if occurrences > inventory_item.quantity
        inventory_item.destroy!
      else
        inventory_item.update!(quantity: inventory_item.quantity - occurrences)
      end
    end

    def parsed_code_counts
      @parsed_code_counts ||= codes.to_s.upcase.scan(/[A-Z]*\s*-?\s*\d+/)
                                   .map { |token| token.gsub(/[^A-Z0-9]/, "") }
                                   .tally
    end
end
