require "csv"

csv_path = Rails.root.join("fichas.csv")

unless csv_path.exist?
  raise "No se encontró #{csv_path}."
end

current_group = nil
stickers_loaded = 0

CSV.foreach(csv_path) do |row|
  next if row.compact.blank?

  current_group = row[0].to_s.strip.presence || current_group
  name = row[1].to_s.strip.presence || current_group

  row[2..].to_a.each do |raw_code|
    next if raw_code.blank?

    prefix, number = Sticker.split_code(raw_code)
    next if number.nil?

    sticker = Sticker.find_or_initialize_by(prefix: prefix, number: number)
    sticker.group_name = current_group.to_s
    sticker.name = name
    sticker.save!
    stickers_loaded += 1 if sticker.previously_new_record?
  end
end

puts "Stickers cargados: #{Sticker.count} (#{stickers_loaded} nuevos)."
puts "Codigo de invitacion disponible: #{StickerSwap::RuntimeConfig.registration_code}"
