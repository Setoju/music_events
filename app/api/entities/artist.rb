module Entities
  class Artist < Grape::Entity
    expose :id
    expose :name
    expose :genre
    expose :bio
    expose :country
    expose :website
  end
end
