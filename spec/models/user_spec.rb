require 'rails_helper'

RSpec.describe User, type: :model do
  it 'normalizes the email before validation' do
    user = build(:user, email: '  MIXED@Example.COM  ')

    user.validate

    expect(user.email).to eq('mixed@example.com')
  end

  it 'finds a user from a password reset token' do
    user = create(:user)

    expect(described_class.find_by_password_reset_token!(user.password_reset_token)).to eq(user)
  end

  it 'disables offer notifications on create by default' do
    user = described_class.create!(
      email: 'new-user@example.com',
      username: 'nuevo_usuario',
      password: 'password123',
      password_confirmation: 'password123'
    )

    expect(user.receive_offer_notifications).to be(false)
  end

  describe '#duplicate_codes_text' do
    it 'lists repeated stickers in catalog order and repeats each copy' do
      user = create(:user)
      aa1 = create(:sticker, prefix: 'ZZTA', number: 10_001, group_name: 'Grupo QA')
      aa2 = create(:sticker, prefix: 'ZZTA', number: 10_002, group_name: 'Grupo QA')
      bb1 = create(:sticker, prefix: 'ZZTB', number: 10_001, group_name: 'Grupo QA')

      create(:inventory_item, :duplicate, user: user, sticker: bb1, quantity: 1)
      create(:inventory_item, :duplicate, user: user, sticker: aa2, quantity: 2)
      create(:inventory_item, :duplicate, user: user, sticker: aa1, quantity: 1)

      expect(user.duplicate_codes_text).to eq('ZZTA10001, ZZTA10002, ZZTA10002, ZZTB10001')
    end

    it 'keeps SCO before PAN in exports' do
      user = create(:user)
      pan = create(:sticker, prefix: 'PAN', number: 15, group_name: 'Grupo QC')
      sco = create(:sticker, prefix: 'SCO', number: 7, group_name: 'Grupo QC')

      create(:inventory_item, :duplicate, user: user, sticker: pan, quantity: 1)
      create(:inventory_item, :duplicate, user: user, sticker: sco, quantity: 1)

      expect(user.duplicate_codes_text).to eq('SCO7, PAN15')
    end
  end

  describe '#missing_codes_text' do
    it 'lists missing stickers in catalog order' do
      user = create(:user)
      aa1 = create(:sticker, prefix: 'ZZTC', number: 10_001, group_name: 'Grupo QB')
      aa2 = create(:sticker, prefix: 'ZZTC', number: 10_002, group_name: 'Grupo QB')
      bb1 = create(:sticker, prefix: 'ZZTD', number: 10_001, group_name: 'Grupo QB')

      create(:inventory_item, user: user, sticker: bb1)
      create(:inventory_item, user: user, sticker: aa2)
      create(:inventory_item, user: user, sticker: aa1)

      expect(user.missing_codes_text).to eq('ZZTC10001, ZZTC10002, ZZTD10001')
    end
  end
end
