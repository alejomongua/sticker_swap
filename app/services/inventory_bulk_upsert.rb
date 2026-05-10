class InventoryBulkUpsert
  Conflict = Struct.new(:code, :previous_status, :new_status, keyword_init: true)

  Result = Struct.new(:saved_count, :unknown_codes, :error_message, :conflicts, keyword_init: true) do
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
    return Result.new(saved_count: 0, unknown_codes: [], error_message: "Debes ingresar al menos una figura.", conflicts: []) if parsed_code_counts.empty?
    return Result.new(saved_count: 0, unknown_codes: [], error_message: "El estado del inventario no es válido.", conflicts: []) unless InventoryItem.statuses.key?(status)
    return Result.new(saved_count: 0, unknown_codes: [], error_message: "La cantidad debe ser un entero mayor a 0.", conflicts: []) if duplicate? && parsed_quantity.nil?

    stickers_by_code = parsed_code_counts.keys.index_with { |code| Sticker.find_by_code(code) }
    unknown_codes = stickers_by_code.select { |_code, sticker| sticker.nil? }.keys
    conflicts = []

    InventoryItem.transaction do
      stickers_by_code.each do |code, sticker|
        next if sticker.nil?

        inventory_item = user.inventory_items.find_or_initialize_by(sticker: sticker)
        previous_status = inventory_item.status

        if previous_status.present? && previous_status != status
          conflicts << Conflict.new(code: code, previous_status: previous_status, new_status: status)
        end

        inventory_item.quantity = next_quantity_for(
          inventory_item,
          occurrences: parsed_code_counts.fetch(code),
          previous_status: previous_status
        )
        inventory_item.status = status
        inventory_item.save!
      end
    end

    Result.new(saved_count: stickers_by_code.values.compact.size, unknown_codes: unknown_codes, error_message: nil, conflicts: conflicts)
  rescue ActiveRecord::RecordInvalid => error
    Result.new(saved_count: 0, unknown_codes: [], error_message: error.record.errors.full_messages.to_sentence, conflicts: [])
  end

  private
    attr_reader :codes, :quantity, :status, :user

    def duplicate?
      status == "duplicate"
    end

    def next_quantity_for(inventory_item, occurrences: 1, previous_status: nil)
      return 1 unless duplicate?

      increment = parsed_quantity * occurrences
      return increment if inventory_item.new_record? || previous_status == "missing"

      inventory_item.quantity + increment
    end

    def parsed_quantity
      @parsed_quantity ||= begin
        value = Integer(quantity.presence || 1, exception: false)
        value if value&.positive?
      end
    end

    def parsed_code_counts
      @parsed_code_counts ||= codes.to_s.upcase.scan(/[A-Z]*\s*-?\s*\d+/)
                                   .map { |token| token.gsub(/[^A-Z0-9]/, "") }
                                   .tally
    end
end
