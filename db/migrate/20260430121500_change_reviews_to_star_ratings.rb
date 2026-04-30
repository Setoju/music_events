class ChangeReviewsToStarRatings < ActiveRecord::Migration[8.1]
  def up
    execute "UPDATE reviews SET rating = rating + 1"
    add_check_constraint :reviews, "rating BETWEEN 1 AND 5", name: "reviews_rating_between_1_and_5"
  end

  def down
    remove_check_constraint :reviews, name: "reviews_rating_between_1_and_5"
    execute "UPDATE reviews SET rating = rating - 1"
  end
end
