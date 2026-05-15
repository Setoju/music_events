require 'rails_helper'

RSpec.describe EventContext, type: :model do
  describe '#weather_error_code' do
    it 'returns mapped code when weather_status is failed' do
      ec = EventContext.new(weather_status: 'failed', weather_error: 'Request timed out')
      expect(ec.weather_error_code).to eq('provider_timeout')
    end

    it 'returns nil when not failed' do
      ec = EventContext.new(weather_status: 'success', weather_error: 'Request timed out')
      expect(ec.weather_error_code).to be_nil
    end
  end
end
require 'rails_helper'

RSpec.describe EventContext, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:event) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:event_id) }

    it 'enforces unique event_id' do
      existing_context = create(:event_context)
      duplicate = build(:event_context, event: existing_context.event)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:event_id]).to include('has already been taken')
    end
  end

  describe 'scopes' do
    it 'returns only pending weather contexts' do
      pending_context = create(:event_context, :weather_pending)
      create(:event_context, :weather_failed)

      expect(described_class.weather_pending).to contain_exactly(pending_context)
    end

    it 'returns only failed weather contexts' do
      failed_context = create(:event_context, :weather_failed)
      create(:event_context, :weather_pending)

      expect(described_class.weather_failed).to contain_exactly(failed_context)
    end
  end

  describe '#weather_fresh?' do
    it 'returns true when expires_at is in the future' do
      context = build(:event_context, expires_at: 1.hour.from_now)

      expect(context.weather_fresh?).to be(true)
    end

    it 'returns false when expires_at is in the past' do
      context = build(:event_context, expires_at: 1.hour.ago)

      expect(context.weather_fresh?).to be(false)
    end
  end

  describe '#weather_available?' do
    it 'returns true only when status is success and data is present' do
      context = build(:event_context, :with_weather)

      expect(context.weather_available?).to be(true)
    end

    it 'returns false when data is missing' do
      context = build(:event_context, weather_data: {}, weather_status: 'success')

      expect(context.weather_available?).to be(false)
    end

    it 'returns false when status is not success' do
      context = build(:event_context, weather_status: 'failed', weather_data: { 'list' => [] })

      expect(context.weather_available?).to be(false)
    end
  end

  describe 'dependent destroy' do
    it 'is removed when its event is destroyed' do
      event = create(:event)
      context = create(:event_context, event: event)

      expect { event.destroy }.to change(described_class, :count).by(-1)
      expect { context.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end