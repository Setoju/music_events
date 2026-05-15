require 'rails_helper'

RSpec.describe WeatherErrorMapper, type: :service do
  describe '.map' do
    it 'maps timeout messages to provider_timeout' do
      expect(WeatherErrorMapper.map('Request timed out while contacting provider')).to eq('provider_timeout')
    end

    it 'maps rate limit messages to rate_limited' do
      expect(WeatherErrorMapper.map('HTTP 429 Too Many Requests')).to eq('rate_limited')
    end

    it 'maps no data messages to no_data' do
      expect(WeatherErrorMapper.map('No data returned')).to eq('no_data')
    end

    it 'returns unknown_error for unmapped messages' do
      expect(WeatherErrorMapper.map('some random failure')).to eq('unknown_error')
    end
  end
end
