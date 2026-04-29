require "rails_helper"

RSpec.describe User, type: :model do
  subject(:user) { build(:user) }

  it { is_expected.to have_many(:bookings) }
  it { is_expected.to have_many(:booked_events).through(:bookings) }
  it { is_expected.to have_many(:reviews) }

  it { is_expected.to validate_presence_of(:email) }
  it { is_expected.to validate_uniqueness_of(:email).case_insensitive }
  it { is_expected.to allow_value("user@example.com").for(:email) }
  it { is_expected.not_to allow_value("invalid-email").for(:email) }
  it { is_expected.to define_enum_for(:role).with_values(user: 0, admin: 1) }

  it "normalizes email before validation" do
    user.email = "  USER@Example.COM "
    user.valid?
    expect(user.email).to eq("user@example.com")
  end

  it "defaults role to user" do
    expect(create(:user).role).to eq("user")
  end
end
