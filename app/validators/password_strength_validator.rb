class PasswordStrengthValidator < ActiveModel::Validator
  MINIMUM_LENGTH = 12
  REQUIREMENTS = {
    uppercase: /[A-Z]/,
    lowercase: /[a-z]/,
    number: /\d/,
    special: /[!@#$%^&*()_+\-=\[\]{};':"\\|,.<>\/?]/
  }.freeze

  def validate(record)
    password = record.password

    # Check minimum length
    if password.blank? || password.length < MINIMUM_LENGTH
      record.errors.add(:password, "must be at least #{MINIMUM_LENGTH} characters long")
      return
    end

    # Check for required character types
    missing_requirements = []
    missing_requirements << "uppercase letter" unless password.match?(REQUIREMENTS[:uppercase])
    missing_requirements << "lowercase letter" unless password.match?(REQUIREMENTS[:lowercase])
    missing_requirements << "number" unless password.match?(REQUIREMENTS[:number])
    missing_requirements << "special character" unless password.match?(REQUIREMENTS[:special])

    if missing_requirements.any?
      record.errors.add(:password, "must contain at least one #{missing_requirements.join(", ")}")
    end

    # Check for common passwords
    if common_password?(password)
      record.errors.add(:password, "is too common. Please choose a stronger password")
    end
  end

  private

  def common_password?(password)
    common_passwords = [
      "password", "12345678", "qwerty", "abc123", "letmein", "welcome",
      "monkey", "1234567", "123456", "password123", "admin", "root"
    ].freeze

    common_passwords.any? { |pwd| password.downcase.include?(pwd) }
  end
end
