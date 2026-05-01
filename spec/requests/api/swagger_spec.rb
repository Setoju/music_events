require "rails_helper"

RSpec.describe "Swagger API", type: :request do
  it "serves the generated swagger document" do
    get "/api/v1/swagger_doc"

    expect(response).to have_http_status(:ok)

    body = JSON.parse(response.body)
    expect(body).to be_a(Hash)
    expect(body["info"]["title"]).to eq("Music Events API")
    expect(body["paths"]).to be_present
  end
end
