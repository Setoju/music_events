class ReviewPolicy < ApplicationPolicy
  def index?
    true
  end

  def create?
    authenticated?
  end

  def update?
    authenticated?
  end
end
