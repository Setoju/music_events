class BookingPolicy < ApplicationPolicy
  def create?
    authenticated?
  end

  def index?
    authenticated?
  end
end
