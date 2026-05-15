require 'rails_helper'

RSpec.describe FetchWeatherJob, type: :job do
  include ActiveJob::TestHelper

  let(:event) { create(:event) }

  before do
    allow(WeatherProvider).to receive(:fetch)
    clear_enqueued_jobs
    clear_performed_jobs
  end

  it 'stores successful weather results on the event context' do
    allow(WeatherProvider).to receive(:fetch).and_return(
      success: true,
      data: { 'list' => [ { 'dt' => 1 } ] },
      error: nil
    )

    described_class.perform_now(event.id)

    expect(event.reload.event_context.weather_status).to eq('success')
    expect(event.event_context.weather_data['list']).to eq([ { 'dt' => 1 } ])
    expect(event.event_context.weather_fetched_at).to be_present
    expect(event.event_context.expires_at).to be_present
  end

  it 'marks the event context as failed when the provider returns an error' do
    allow(WeatherProvider).to receive(:fetch).and_return(
      success: false,
      data: nil,
      error: 'Timeout: execution expired'
    )

    described_class.perform_now(event.id)

    expect(event.reload.event_context.weather_status).to eq('failed')
    expect(event.event_context.weather_error).to eq('Timeout: execution expired')
  end

  it 'completes gracefully when the event no longer exists' do
    event_id = event.id
    event.destroy!

    expect { described_class.perform_now(event_id) }.not_to raise_error
  end

  it 'captures timeout errors from the provider' do
    allow(WeatherProvider).to receive(:fetch).and_return(
      success: false,
      data: nil,
      error: 'Timeout: execution expired'
    )

    expect { described_class.perform_now(event.id) }.not_to raise_error
    expect(event.reload.event_context.weather_status).to eq('failed')
  end

  it 'retries unexpected errors' do
    allow(WeatherProvider).to receive(:fetch).and_raise(StandardError, 'temporary failure')

    expect { described_class.perform_now(event.id) }
      .to have_enqueued_job(described_class).with(event.id).once
  end
end