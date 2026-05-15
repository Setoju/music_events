class User < ApplicationRecord
  has_secure_password
  enum :role, { user: 0, admin: 1 }

  has_many :bookings, dependent: :destroy
  has_many :booked_events, through: :bookings, source: :event
  has_many :reviews, dependent: :destroy

  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, presence: true, length: { minimum: 8 }, if: -> { new_record? || password.present? }
  validates_with PasswordStrengthValidator, if: -> { new_record? || password.present? }

  before_validation :normalize_email

  private

  def normalize_email
    self.email = email.to_s.downcase.strip
  end
end
