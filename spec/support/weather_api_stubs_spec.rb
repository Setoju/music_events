require 'rails_helper'

RSpec.describe WeatherApiStubs do
  include WebMock::API

  before do
    WebMock.reset!
  end

  it 'stubs a successful weather response' do
    stub_weather_success(40.7128, -74.0060)

    response = Net::HTTP.get_response(URI('https://api.open-meteo.com/v1/forecast?latitude=40.7128&longitude=-74.006'))

    expect(response).to be_a(Net::HTTPSuccess)
    assert_weather_called_with(40.7128, -74.0060)
  end

  it 'stubs a failed weather response' do
    stub_weather_failure(40.7128, -74.0060, 500)

    response = Net::HTTP.get_response(URI('https://api.open-meteo.com/v1/forecast?latitude=40.7128&longitude=-74.006'))

    expect(response.code).to eq('500')
    assert_weather_called_with(40.7128, -74.0060)
  end
end