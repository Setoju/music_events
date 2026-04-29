require "rails_helper"

RSpec.describe RevokedJwtToken, type: :model do
  subject(:revoked_token) { build(:revoked_jwt_token) }

  it { is_expected.to validate_presence_of(:jti) }
  it { is_expected.to validate_uniqueness_of(:jti) }
  it { is_expected.to validate_presence_of(:exp) }

  describe ".revoked?" do
    it "returns true when jti exists in denylist" do
      token = create(:revoked_jwt_token)
      expect(described_class.revoked?(token.jti)).to be(true)
    end

    it "returns false when jti does not exist in denylist" do
      expect(described_class.revoked?("missing-jti")).to be(false)
    end
  end
end
