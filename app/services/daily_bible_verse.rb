require "yaml"

class DailyBibleVerse
  Verse = Data.define(:reference, :text, :theme)
  DATA_PATH = Rails.root.join("config", "daily_bible_verses.yml")

  class << self
    def for(date = Date.current)
      date = date.to_date
      verses.fetch((date.jd - 1) % verses.length)
    end

    def verses
      @verses ||= load_verses
    end

    private

    def load_verses
      records = YAML.safe_load_file(DATA_PATH, aliases: false)

      unless records.is_a?(Array) && records.any?
        raise "Daily Bible verse collection must contain at least one verse"
      end

      records.map.with_index do |record, index|
        attributes = record.to_h.transform_keys(&:to_s)
        reference = attributes.fetch("reference", "").to_s.strip
        text = attributes.fetch("text", "").to_s.strip
        theme = attributes.fetch("theme", "").to_s.strip

        if reference.blank? || text.blank? || theme.blank?
          raise "Daily Bible verse entry #{index + 1} is incomplete"
        end

        Verse.new(reference:, text:, theme:).freeze
      end.freeze
    end
  end
end
