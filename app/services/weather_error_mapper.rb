class WeatherErrorMapper
  MAPPING_PATH = Rails.root.join("config", "weather_error_mapping.yml")

  def self.mapping
    @mapping ||= if File.exist?(MAPPING_PATH)
                   YAML.load_file(MAPPING_PATH) || {}
    else
                   {}
    end
  end

  def self.map(raw_error)
    return nil if raw_error.blank?

    text = raw_error.to_s.downcase

    mapping.each do |code, patterns|
      Array(patterns).each do |pat|
        return code if text.include?(pat.to_s.downcase)
      end
    end

    "unknown_error"
  end
end
