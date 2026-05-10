require 'rails_helper'

RSpec.describe Sticker, type: :model do
  describe ".catalog_order" do
    it "orders stickers by the configured prefix sequence" do
      pan = create(:sticker, prefix: "PAN", number: 2)
      arg = create(:sticker, prefix: "ARG", number: 1)
      mex = create(:sticker, prefix: "MEX", number: 3)
      fwc = create(:sticker, prefix: "FWC", number: 5)
      blank_fwc = create(:sticker, prefix: "", number: 0)
      unknown = create(:sticker, prefix: "ZZZ", number: 1)

      expect(described_class.catalog_order).to eq([ blank_fwc, fwc, mex, arg, pan, unknown ])
    end
  end

  it 'parses a code with prefix and number' do
    expect(described_class.split_code('arg 12')).to eq([ 'ARG', 12 ])
  end

  it 'parses codes with three-letter prefixes' do
    expect(described_class.split_code('fwc-3')).to eq([ 'FWC', 3 ])
  end

  it 'formats codes without prefix with a leading zero when needed' do
    sticker = build(:sticker, prefix: '', number: 7)

    expect(sticker.code).to eq('07')
  end
end
