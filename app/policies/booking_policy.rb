class BookingPolicy < ApplicationPolicy
  def create?
    authenticated?
  end

  def index?
    authenticated?
  end

  def destroy?
    authenticated?
  end
end
