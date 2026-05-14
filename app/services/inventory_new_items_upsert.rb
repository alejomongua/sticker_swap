class InventoryNewItemsUpsert
  Result = Struct.new(:processed_count, :unknown_codes, :error_message, keyword_init: true) do
    def success?
      error_message.blank?
    end
  end

  def initialize(user:, codes:)
    @codes = codes
    @user = user
  end

  def call
    return Result.new(processed_count: 0, unknown_codes: [], error_message: "Debes ingresar al menos una figura.") if parsed_code_counts.empty?

    stickers_by_code = parsed_code_counts.keys.index_with { |code| Sticker.find_by_code(code) }
    unknown_codes = stickers_by_code.select { |_code, sticker| sticker.nil? }.keys
    processed_count = 0

    InventoryItem.transaction do
      stickers_by_code.each do |code, sticker|
        next if sticker.nil?

        register_occurrences!(sticker, occurrences: parsed_code_counts.fetch(code))
        processed_count += 1
      end
    end

    Result.new(processed_count: processed_count, unknown_codes: unknown_codes, error_message: nil)
  rescue ActiveRecord::RecordInvalid => error
    Result.new(processed_count: 0, unknown_codes: [], error_message: error.record.errors.full_messages.to_sentence)
  end

  private
    attr_reader :codes, :user

    def register_occurrences!(sticker, occurrences:)
      inventory_item = user.inventory_items.find_by(sticker: sticker)

      if inventory_item&.missing?
        inventory_item.destroy!
        extra_duplicates = occurrences - 1
        return if extra_duplicates.zero?

        user.inventory_items.create!(sticker: sticker, status: :duplicate, quantity: extra_duplicates)
        return
      end

      if inventory_item&.duplicate?
        inventory_item.update!(quantity: inventory_item.quantity + occurrences)
      else
        user.inventory_items.create!(sticker: sticker, status: :duplicate, quantity: occurrences)
      end
    end

    def parsed_code_counts
      @parsed_code_counts ||= codes.to_s.upcase.scan(/[A-Z]*\s*-?\s*\d+/)
                                   .map { |token| token.gsub(/[^A-Z0-9]/, "") }
                                   .tally
    end
end