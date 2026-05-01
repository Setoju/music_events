require "rails_helper"

RSpec.describe "Auth API", type: :request do
  describe "POST /api/v1/auth/sign_up" do
    it "creates user and returns bearer token with strong password" do
      params = {
        email: "new_user@example.com",
        password: "SecurePass123!",
        password_confirmation: "SecurePass123!"
      }

      expect do
        post "/api/v1/auth/sign_up", params: params
      end.to change(User, :count).by(1)

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body["token"]).to be_present
      expect(body.dig("user", "email")).to eq("new_user@example.com")
    end

    it "rejects weak passwords" do
      params = {
        email: "weak_user@example.com",
        password: "weak",
        password_confirmation: "weak"
      }

      post "/api/v1/auth/sign_up", params: params

      expect(response).to have_http_status(422)
      body = JSON.parse(response.body)
      expect(body["message"]).to include("must be at least 12 characters long")
    end

    it "rejects passwords without uppercase letters" do
      params = {
        email: "no_upper@example.com",
        password: "nouppercase123!",
        password_confirmation: "nouppercase123!"
      }

      post "/api/v1/auth/sign_up", params: params

      expect(response).to have_http_status(422)
      body = JSON.parse(response.body)
      expect(body["message"]).to include("uppercase letter")
    end

    it "rejects passwords without special characters" do
      params = {
        email: "no_special@example.com",
        password: "NoSpecial1234",
        password_confirmation: "NoSpecial1234"
      }

      post "/api/v1/auth/sign_up", params: params

      expect(response).to have_http_status(422)
      body = JSON.parse(response.body)
      expect(body["message"]).to include("special character")
    end

    it "rejects common passwords" do
      params = {
        email: "common_pass@example.com",
        password: "Password123!pass",
        password_confirmation: "Password123!pass"
      }

      post "/api/v1/auth/sign_up", params: params

      expect(response).to have_http_status(422)
      body = JSON.parse(response.body)
      expect(body["message"]).to include("too common")
    end
  end

  describe "POST /api/v1/auth/sign_in" do
    let!(:user) { create(:user, email: "login@example.com") }

    it "returns token for valid credentials" do
      post "/api/v1/auth/sign_in", params: { email: "login@example.com", password: "SecurePass123!" }

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

  describe "GET /api/v1/auth/password_requirements" do
    it "returns password strength requirements" do
      get "/api/v1/auth/password_requirements"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      requirements = body["password_requirements"]

      expect(requirements["minimum_length"]).to eq(12)
      expect(requirements["requirements"]).to be_an(Array)
      expect(requirements["requirements"].length).to eq(4)
      expect(requirements["requirements"]).to include("At least one uppercase letter (A-Z)")
      expect(requirements["requirements"]).to include("At least one lowercase letter (a-z)")
      expect(requirements["requirements"]).to include("At least one number (0-9)")
      expect(requirements["requirements"].any? { |r| r.include?("special character") }).to be true
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
