require 'rails_helper'

RSpec.describe Sticker, type: :model do
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
