class Sticker < ApplicationRecord
  PREFIX_ORDER = %w[
    FWC
    MEX
    RSA
    KOR
    CZE
    CAN
    BIH
    QAT
    SUI
    BRA
    MAR
    HAI
    SCO
    USA
    PAR
    AUS
    TUR
    GER
    CUW
    CIV
    ECU
    NED
    JPN
    SWE
    TUN
    BEL
    EGY
    IRN
    NZL
    ESP
    CPV
    KSA
    URU
    FRA
    SEN
    IRQ
    NOR
    ARG
    ALG
    AUT
    JOR
    POR
    COD
    UZB
    COL
    ENG
    CRO
    GHA
    PAN
  ].freeze
  PREFIX_ORDER_INDEX = PREFIX_ORDER.each_with_index.to_h.freeze

  has_many :inventory_items, dependent: :destroy

  normalizes :group_name, with: ->(value) { value.to_s.strip }
  normalizes :name, with: ->(value) { value.to_s.strip }
  normalizes :prefix, with: ->(value) { value.to_s.strip.upcase }

  validates :number, numericality: { greater_than_or_equal_to: 0 }, presence: true
  validates :prefix, uniqueness: { scope: :number }

  scope :catalog_order, -> {
    order(
      Arel.sql(Sticker.prefix_order_sql_for),
      Arel.sql(Sticker.normalized_prefix_sql_for),
      :number
    )
  }

  def code
    prefix.present? ? "#{prefix}#{number}" : format("%02d", number)
  end

  def display_name
    name.present? ? "#{code} · #{name}" : code
  end

  def sort_key
    prefix_rank, normalized_prefix = self.class.prefix_sort_components(prefix)

    [ prefix_rank, normalized_prefix, number ]
  end

  def self.find_by_code(raw_code)
    prefix, number = split_code(raw_code)
    return if number.nil?

    find_by(prefix: prefix, number: number)
  end

  def self.split_code(raw_code)
    token = raw_code.to_s.upcase.gsub(/[^A-Z0-9]/, "")
    match = token.match(/\A([A-Z]*)(\d+)\z/)
    return [ nil, nil ] unless match

    [ match[1], match[2].to_i ]
  end

  def self.sorted_prefixes(prefixes)
    prefixes.compact_blank.sort_by { |prefix| prefix_sort_components(prefix) }
  end

  def self.prefix_sort_components(raw_prefix)
    normalized_prefix = normalize_prefix_for_sort(raw_prefix)

    [ PREFIX_ORDER_INDEX.fetch(normalized_prefix, PREFIX_ORDER.length), normalized_prefix ]
  end

  def self.prefix_order_sql_for(column_name = "#{table_name}.prefix")
    normalized_prefix_sql = normalized_prefix_sql_for(column_name)
    clauses = PREFIX_ORDER.each_with_index.map do |prefix, index|
      "WHEN #{normalized_prefix_sql} = #{connection.quote(prefix)} THEN #{index}"
    end.join(" ")

    "CASE #{clauses} ELSE #{PREFIX_ORDER.length} END"
  end

  def self.normalized_prefix_sql_for(column_name = "#{table_name}.prefix")
    "COALESCE(NULLIF(#{column_name}, ''), 'FWC')"
  end

  def self.normalize_prefix_for_sort(raw_prefix)
    raw_prefix.to_s.strip.upcase.presence || "FWC"
  end
end
