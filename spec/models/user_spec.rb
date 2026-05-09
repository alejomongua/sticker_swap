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
end
