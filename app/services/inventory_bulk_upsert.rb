class InventoryBulkUpsert
  Result = Struct.new(:saved_count, :unknown_codes, :error_message, keyword_init: true) do
    def success?
      error_message.blank?
    end
  end

  def initialize(user:, status:, codes:, quantity: nil)
    @codes = codes
    @quantity = quantity
    @status = status
    @user = user
  end

  def call
    return Result.new(saved_count: 0, unknown_codes: [], error_message: "Debes ingresar al menos una figura.") if parsed_codes.empty?
    return Result.new(saved_count: 0, unknown_codes: [], error_message: "El estado del inventario no es válido.") unless InventoryItem.statuses.key?(status)
    return Result.new(saved_count: 0, unknown_codes: [], error_message: "La cantidad debe ser un entero mayor a 0.") if duplicate? && parsed_quantity.nil?

    stickers_by_code = parsed_codes.index_with { |code| Sticker.find_by_code(code) }
    unknown_codes = stickers_by_code.select { |_code, sticker| sticker.nil? }.keys

    InventoryItem.transaction do
      stickers_by_code.values.compact.each do |sticker|
        inventory_item = user.inventory_items.find_or_initialize_by(sticker: sticker)
        inventory_item.status = status
        inventory_item.quantity = next_quantity_for(inventory_item)
        inventory_item.save!
      end
    end

    Result.new(saved_count: stickers_by_code.values.compact.size, unknown_codes: unknown_codes, error_message: nil)
  rescue ActiveRecord::RecordInvalid => error
    Result.new(saved_count: 0, unknown_codes: [], error_message: error.record.errors.full_messages.to_sentence)
  end

  private
    attr_reader :codes, :quantity, :status, :user

    def duplicate?
      status == "duplicate"
    end

    def next_quantity_for(inventory_item)
      return 1 unless duplicate?
      return parsed_quantity if inventory_item.new_record? || inventory_item.missing?

      inventory_item.quantity + parsed_quantity
    end

    def parsed_quantity
      @parsed_quantity ||= begin
        value = Integer(quantity.presence || 1, exception: false)
        value if value&.positive?
      end
    end

    def parsed_codes
      @parsed_codes ||= codes.to_s.upcase.scan(/[A-Z]*\s*-?\s*\d+/).map { |token| token.gsub(/[^A-Z0-9]/, "") }.uniq
    end
end
