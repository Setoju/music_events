require "rails_helper"

RSpec.describe Event, type: :model do
  subject(:event) { build(:event) }

  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_presence_of(:venue) }
  it { is_expected.to validate_presence_of(:city) }
  it { is_expected.to validate_presence_of(:starts_at) }
  it { is_expected.to validate_numericality_of(:ticket_price).is_greater_than_or_equal_to(0).allow_nil }
end
