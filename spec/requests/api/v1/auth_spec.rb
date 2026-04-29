require "rails_helper"

RSpec.describe "Auth API", type: :request do
  describe "POST /api/v1/auth/sign_up" do
    it "creates user and returns bearer token" do
      params = {
        email: "new_user@example.com",
        password: "password123",
        password_confirmation: "password123"
      }

      expect do
        post "/api/v1/auth/sign_up", params: params
      end.to change(User, :count).by(1)

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body["token"]).to be_present
      expect(body.dig("user", "email")).to eq("new_user@example.com")
    end
  end

  describe "POST /api/v1/auth/sign_in" do
    let!(:user) { create(:user, email: "login@example.com", password: "password123", password_confirmation: "password123") }

    it "returns token for valid credentials" do
      post "/api/v1/auth/sign_in", params: { email: "login@example.com", password: "password123" }

      expect([ 200, 201 ]).to include(response.status)
      body = JSON.parse(response.body)
      expect(body["token"]).to be_present
    end

    it "returns unauthorized for invalid credentials" do
      post "/api/v1/auth/sign_in", params: { email: "login@example.com", password: "wrong-password" }

      expect(response).to have_http_status(:unauthorized)
      expect(JSON.parse(response.body)["error"]).to eq("Invalid email or password")
    end
  end

  describe "GET /api/v1/auth/me" do
    let!(:user) { create(:user) }
    let(:token) { JwtToken.encode(user_id: user.id) }

    it "returns unauthorized without bearer token" do
      get "/api/v1/auth/me"

      expect(response).to have_http_status(:unauthorized)
    end

    it "returns current user with valid bearer token" do
      get "/api/v1/auth/me", headers: { "Authorization" => "Bearer #{token}" }

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["email"]).to eq(user.email)
    end

    it "returns unauthorized with invalid bearer token" do
      get "/api/v1/auth/me", headers: { "Authorization" => "Bearer invalid.token.value" }

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "DELETE /api/v1/auth/logout" do
    let!(:user) { create(:user) }
    let(:token) { JwtToken.encode(user_id: user.id) }
    let(:headers) { { "Authorization" => "Bearer #{token}" } }

    it "returns unauthorized without bearer token" do
      delete "/api/v1/auth/logout"

      expect(response).to have_http_status(:unauthorized)
    end

    it "revokes current token and prevents further use" do
      expect do
        delete "/api/v1/auth/logout", headers: headers
      end.to change(RevokedJwtToken, :count).by(1)

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["message"]).to eq("Logged out successfully")

      get "/api/v1/auth/me", headers: headers
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
