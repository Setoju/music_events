class ReviewPolicy < ApplicationPolicy
  def index?
    true
  end

  def create?
    authenticated?
  end

  def show?
    true
  end

  def update?
    authenticated? && user == record.user
  end

  def destroy?
    authenticated? && user == record.user
  end
end
