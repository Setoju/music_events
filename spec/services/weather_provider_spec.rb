require 'rails_helper'

RSpec.describe WeatherProvider do
  let(:event) { build(:event, latitude: 40.7128, longitude: -74.0060) }

  describe '.fetch' do
    it 'returns success with weather data' do
      stub_weather_success(40.7128, -74.0060)

      result = described_class.fetch(event)

      expect(result[:success]).to be(true)
      expect(result[:error]).to be_nil
      expect(result[:data]['list']).to be_an(Array)
      expect(result[:data]['list'].length).to eq(2)
      expect(result[:data]['provider']).to eq('open-meteo')
    end

    it 'returns an error for missing coordinates' do
      event.latitude = nil

      result = described_class.fetch(event)

      expect(result).to eq(success: false, data: nil, error: 'Missing coordinates')
    end

    it 'returns an error for HTTP 401 responses' do
      stub_weather_failure(40.7128, -74.0060, 401)

      result = described_class.fetch(event)

      expect(result[:success]).to be(false)
      expect(result[:error]).to include('Error 401')
    end

    it 'returns an error for HTTP 500 responses' do
      stub_weather_failure(40.7128, -74.0060, 500)

      result = described_class.fetch(event)

      expect(result[:success]).to be(false)
      expect(result[:error]).to include('Error 500')
    end

    it 'returns an error for malformed JSON' do
      stub_request(:get, %r{api\.open-meteo\.com/v1/forecast})
        .to_return(status: 200, body: 'not-json', headers: { 'Content-Type' => 'application/json' })

      result = described_class.fetch(event)

      expect(result).to eq(success: false, data: nil, error: 'Invalid JSON response')
    end

    it 'returns an error for timeouts' do
      stub_request(:get, %r{api\.open-meteo\.com/v1/forecast}).to_timeout

      result = described_class.fetch(event)

      expect(result[:success]).to be(false)
      expect(result[:error]).to start_with('Timeout:')
    end

    it 'returns an error for connection failures' do
      stub_request(:get, %r{api\.open-meteo\.com/v1/forecast}).to_raise(Faraday::ConnectionFailed.new('failed'))

      result = described_class.fetch(event)

      expect(result).to eq(success: false, data: nil, error: 'Connection error: failed')
    end

    it 'retries failed requests and succeeds on the second attempt' do
      stub_request(:get, %r{api\.open-meteo\.com/v1/forecast})
        .to_return(status: 500, body: { reason: 'Error 500' }.to_json, headers: { 'Content-Type' => 'application/json' })
        .then
        .to_return(status: 200, body: File.read(Rails.root.join('spec/fixtures/weather_api_response.json')), headers: { 'Content-Type' => 'application/json' })

      result = described_class.fetch(event)

      expect(result[:success]).to be(true)
      expect(WebMock).to have_requested(:get, %r{api\.open-meteo\.com/v1/forecast}).twice
    end

    it 'configures a five second timeout and retry middleware' do
      client = described_class.send(:http_client)
      expect(client.options.timeout).to eq(10)
      expect(client.options.open_timeout).to eq(10)
      expect(client.builder.handlers.map(&:name)).to include('Faraday::Retry::Middleware')
    end
  end
end