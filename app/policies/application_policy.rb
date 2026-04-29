class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user || GuestUser.new
    @record = record
  end

  private

  def admin?
    user.respond_to?(:admin?) && user.admin?
  end

  def authenticated?
    user.is_a?(User)
  end
end
