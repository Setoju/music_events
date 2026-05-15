require 'json'

module WeatherApiStubs
  def stub_weather_success(lat, lon)
    response_body = JSON.parse(File.read(Rails.root.join('spec/fixtures/weather_api_response.json')))

    stub_request(:get, "https://api.openweathermap.org/data/2.5/forecast")
      .with(query: hash_including(lat: lat.to_s, lon: lon.to_s))
      .to_return(status: 200, body: response_body.to_json, headers: { 'Content-Type' => 'application/json' })
  end

  def stub_weather_failure(lat, lon, error_code)
    stub_request(:get, "https://api.openweathermap.org/data/2.5/forecast")
      .with(query: hash_including(lat: lat.to_s, lon: lon.to_s))
      .to_return(status: error_code, body: { message: "Error #{error_code}" }.to_json, headers: { 'Content-Type' => 'application/json' })
  end

  def assert_weather_called_with(lat, lon)
    expect(WebMock).to have_requested(:get, "https://api.openweathermap.org/data/2.5/forecast?lat=#{lat}&lon=#{lon}")
  end
end

RSpec.configure do |config|
  config.include WeatherApiStubs
end