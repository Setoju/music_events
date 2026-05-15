require 'rails_helper'

RSpec.describe 'event_context factory' do
  it 'builds a valid event_context' do
    event_context = build(:event_context)

    expect(event_context).to be_valid
    expect(event_context.event).to be_present
  end

  it 'builds a valid event_context with weather data trait' do
    event_context = build(:event_context, :with_weather)

    expect(event_context).to be_valid
    expect(event_context.weather_status).to eq('success')
    expect(event_context.weather_data).to include('list')
  end

  it 'builds a failed weather context' do
    event_context = build(:event_context, :weather_failed)

    expect(event_context).to be_valid
    expect(event_context.weather_status).to eq('failed')
    expect(event_context.weather_error).to be_present
  end
end
