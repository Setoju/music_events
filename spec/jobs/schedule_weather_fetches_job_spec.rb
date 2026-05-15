require 'rails_helper'

RSpec.describe ScheduleWeatherFetchesJob, type: :job do
  include ActiveJob::TestHelper
  include ActiveSupport::Testing::TimeHelpers

  before do
    clear_enqueued_jobs
    clear_performed_jobs
  end

  it 'enqueues fetch jobs for events in the 24 to 24.5 hour window' do
    travel_to(Time.current) do
      in_window = create(:event, starts_at: 24.1.hours.from_now)
      create(:event, starts_at: 20.hours.from_now)
      create(:event, starts_at: 28.hours.from_now)

      expect { described_class.perform_now }.to have_enqueued_job(FetchWeatherJob).with(in_window.id).once
    end
  end

  it 'skips events that already have weather fetched' do
    travel_to(Time.current) do
      fetched_event = create(:event, starts_at: 24.2.hours.from_now)
      create(:event_context, event: fetched_event, weather_fetched_at: 1.hour.ago)

      expect { described_class.perform_now }.not_to have_enqueued_job(FetchWeatherJob).with(fetched_event.id)
    end
  end

  it 'completes without error when no events match the window' do
    travel_to(Time.current) do
      expect { described_class.perform_now }.not_to raise_error
    end
  end

  it 'enqueues many jobs for high volume windows' do
    travel_to(Time.current) do
      events = create_list(:event, 50, starts_at: 24.2.hours.from_now)

      expect { described_class.perform_now }.to have_enqueued_job(FetchWeatherJob).exactly(events.size).times
    end
  end
end
