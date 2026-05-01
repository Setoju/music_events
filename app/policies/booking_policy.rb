class BookingPolicy < ApplicationPolicy
  def create?
    authenticated?
  end

  def index?
    authenticated?
  end

  def show?
    authenticated? && user == record.user
  end

  def destroy?
    authenticated? && user == record.user
  end
end
