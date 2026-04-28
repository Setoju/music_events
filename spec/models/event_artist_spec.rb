require "rails_helper"

RSpec.describe EventArtist, type: :model do
  subject(:event_artist) { build(:event_artist) }

  it { is_expected.to belong_to(:event) }
  it { is_expected.to belong_to(:artist) }
  it { is_expected.to validate_presence_of(:event_id) }
  it { is_expected.to validate_presence_of(:artist_id) }
end
