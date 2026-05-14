class FiguritasAppInventoryParser
  Result = Struct.new(
    :missing_stickers,
    :duplicate_sticker_counts,
    :unknown_codes,
    :conflicting_codes,
    :error_message,
    keyword_init: true
  ) do
    def success?
      error_message.blank?
    end

    def missing_count
      missing_stickers.size
    end

    def duplicate_copies_count
      duplicate_sticker_counts.values.sum
    end

    def duplicate_items_count
      duplicate_sticker_counts.size
    end

    def duplicate_stickers
      duplicate_sticker_counts.keys
    end
  end

  def initialize(text:)
    @text = text
  end

  def call
    parsed_sections = parse_sections
    return failure_result("No se encontraron faltantes ni repetidas en el texto pegado.") if parsed_sections.values.all?(&:empty?)

    conflicting_codes = parsed_sections[:missing].keys & parsed_sections[:duplicate].keys
    return failure_result("El texto importado marca estas fichas como faltantes y repetidas: #{conflicting_codes.sort.join(', ')}.", conflicting_codes: conflicting_codes.sort) if conflicting_codes.any?

    stickers_by_code = all_codes(parsed_sections).index_with { |code| Sticker.find_by_code(code) }
    unknown_codes = stickers_by_code.select { |_code, sticker| sticker.nil? }.keys.sort

    Result.new(
      missing_stickers: known_missing_stickers(parsed_sections[:missing], stickers_by_code),
      duplicate_sticker_counts: known_duplicate_sticker_counts(parsed_sections[:duplicate], stickers_by_code),
      unknown_codes: unknown_codes,
      conflicting_codes: [],
      error_message: nil
    )
  end

  private
    attr_reader :text

    def failure_result(message, conflicting_codes: [])
      Result.new(
        missing_stickers: [],
        duplicate_sticker_counts: {},
        unknown_codes: [],
        conflicting_codes: conflicting_codes,
        error_message: message
      )
    end

    def parse_sections
      result = {
        missing: Hash.new(0),
        duplicate: Hash.new(0)
      }
      current_section = nil

      text.to_s.each_line do |line|
        normalized_line = I18n.transliterate(line.to_s.strip).upcase
        next if normalized_line.blank?

        current_section = :missing and next if normalized_line == "ME FALTAN"
        current_section = :duplicate and next if normalized_line == "REPETIDAS"
        next if current_section.nil?

        parsed_line = parse_section_line(normalized_line)
        next if parsed_line.nil?

        prefix, numbers = parsed_line
        numbers.each do |number|
          result[current_section]["#{prefix}#{number}"] += 1
        end
      end

      result
    end

    def parse_section_line(normalized_line)
      match = normalized_line.match(/\A([A-Z]+)\b[^:]*:\s*(.+)\z/)
      return if match.nil?

      numbers = match[2].scan(/\d+/).map(&:to_i)
      return if numbers.empty?

      [ match[1], numbers ]
    end

    def all_codes(parsed_sections)
      (parsed_sections[:missing].keys + parsed_sections[:duplicate].keys).uniq
    end

    def known_missing_stickers(missing_codes, stickers_by_code)
      missing_codes.each_key.filter_map { |code| stickers_by_code[code] }
                   .sort_by(&:sort_key)
    end

    def known_duplicate_sticker_counts(duplicate_codes, stickers_by_code)
      duplicate_codes.filter_map do |code, quantity|
        sticker = stickers_by_code[code]
        next if sticker.nil?

        [ sticker, quantity ]
      end.sort_by { |sticker, _quantity| sticker.sort_key }.to_h
    end
end