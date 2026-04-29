class RevokedJwtToken < ApplicationRecord
  validates :jti, presence: true, uniqueness: true
  validates :exp, presence: true

  def self.revoked?(jti)
    return false if jti.blank?

    exists?(jti: jti)
  end

  def self.revoke!(jti:, exp:)
    create_or_find_by!(jti: jti) do |record|
      record.exp = exp
    end
  end
end
