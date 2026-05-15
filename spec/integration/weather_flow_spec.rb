require 'rails_helper'

RSpec.describe 'Weather flow', type: :request do
  include ActiveJob::TestHelper
  include ActiveSupport::Testing::TimeHelpers

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('OPENWEATHERMAP_API_KEY').and_return('test-api-key')
    clear_enqueued_jobs
    clear_performed_jobs
  end

  it 'schedules, fetches, stores, and returns weather data' do
    travel_to(Time.current) do
      event = create(:event, starts_at: 24.1.hours.from_now)
      stub_weather_success(event.latitude, event.longitude)

      perform_enqueued_jobs do
        ScheduleWeatherFetchesJob.perform_now
      end

      event.reload
      expect(event.event_context).to be_present
      expect(event.event_context.weather_status).to eq('success')

      get "/api/v1/events/#{event.id}"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["weather"]).to be_present
      expect(body["weather"]["forecast"]).to eq(event.event_context.weather_data)
    end
  end

  it 'handles provider failures without blocking the API response' do
    travel_to(Time.current) do
      event = create(:event, starts_at: 24.2.hours.from_now)
      stub_weather_failure(event.latitude, event.longitude, 500)

      perform_enqueued_jobs do
        ScheduleWeatherFetchesJob.perform_now
      end

      event.reload
      expect(event.event_context.weather_status).to eq('failed')

      get "/api/v1/events/#{event.id}"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["weather"]).to be_present
      expect(body["weather"]["weather_status"]).to eq('failed')
      expect(body["weather"]["weather_error_code"]).to be_a(String)
    end
  end

  it 'only schedules events in the discovery window' do
    travel_to(Time.current) do
      early_event = create(:event, starts_at: 20.hours.from_now)
      in_window_event = create(:event, starts_at: 24.1.hours.from_now)
      late_event = create(:event, starts_at: 28.hours.from_now)

      ScheduleWeatherFetchesJob.perform_now

      expect(enqueued_jobs.map { |job| job[:args].first }).to contain_exactly(in_window_event.id)
      expect(early_event.event_context).to be_nil
      expect(late_event.event_context).to be_nil
    end
  end

  it 'handles transient retries through the provider layer' do
    travel_to(Time.current) do
      event = create(:event, starts_at: 24.3.hours.from_now)
      allow(WeatherProvider).to receive(:fetch).and_return(
        { success: false, data: nil, error: 'Timeout: execution expired' },
        { success: true, data: { 'list' => [ { 'dt' => 1 } ] }, error: nil }
      )

      FetchWeatherJob.perform_now(event.id)
      FetchWeatherJob.perform_now(event.id)

      expect(event.reload.event_context.weather_status).to eq('success')
    end
  end
end