require 'json'

module WeatherApiStubs
  def stub_weather_success(lat, lon)
    response_body = JSON.parse(File.read(Rails.root.join('spec/fixtures/weather_api_response.json')))

    stub_request(:get, "https://api.open-meteo.com/v1/forecast")
      .with(query: hash_including(latitude: lat.to_s, longitude: lon.to_s))
      .to_return(status: 200, body: response_body.to_json, headers: { 'Content-Type' => 'application/json' })
  end

  def stub_weather_failure(lat, lon, error_code)
    stub_request(:get, "https://api.open-meteo.com/v1/forecast")
      .with(query: hash_including(latitude: lat.to_s, longitude: lon.to_s))
      .to_return(status: error_code, body: { reason: "Error #{error_code}" }.to_json, headers: { 'Content-Type' => 'application/json' })
  end

  def assert_weather_called_with(lat, lon)
    expect(WebMock).to have_requested(:get, "https://api.open-meteo.com/v1/forecast")
      .with(query: hash_including(latitude: lat.to_s, longitude: lon.to_s))
  end
end

RSpec.configure do |config|
  config.include WeatherApiStubs
end