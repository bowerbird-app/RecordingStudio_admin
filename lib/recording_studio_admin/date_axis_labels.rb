# frozen_string_literal: true

module RecordingStudioAdmin
  class DateAxisLabels
    BUCKETS = %i[hour day week month year].freeze
    FORMS = %i[axis tooltip].freeze
    LOCALE_PREFIX = "recording_studio.admin.date_axis"

    def self.call(times, bucket: :day, form: :axis)
      new(times, bucket: bucket, form: form).labels
    end

    def initialize(times, bucket:, form:)
      @times = times
      @bucket = coerce_bucket(bucket)
      @form = coerce_form(form)
    end

    def labels
      zoned = @times.map { |value| in_zone(value) }
      zoned.each_with_index.map do |time, index|
        label_at(time, index.zero? ? nil : zoned[index - 1])
      end
    end

    private

    def coerce_bucket(bucket)
      name = bucket.to_sym
      BUCKETS.include?(name) ? name : :day
    end

    def coerce_form(form)
      name = form.to_sym
      return name if FORMS.include?(name)

      raise ArgumentError, "unknown date axis form: #{form.inspect}"
    end

    def in_zone(value)
      return value.in_time_zone if value.respond_to?(:in_time_zone)

      Time.zone.parse(value.to_s)
    end

    def label_at(time, previous)
      case @bucket
      when :hour then hour_label(time, previous)
      when :month then month_label(time, previous)
      when :year then localize(time, :year)
      else day_style_label(time, previous)
      end
    end

    def hour_label(time, previous)
      key = date_changed?(time, previous) ? :hour_with_day : :hour
      localize(time, key).strip
    end

    def date_changed?(time, previous)
      previous.nil? || time.to_date != previous.to_date
    end

    def month_label(time, previous)
      key = month_shows_year?(time, previous) ? :month_with_year : :month
      localize(time, key)
    end

    def month_shows_year?(time, previous)
      return true if previous.nil?
      return true if time.year != previous.year

      time.month == 1
    end

    def day_style_label(time, previous)
      text = localize(time, day_key(time, previous))
      return text unless week_tooltip?

      I18n.t("#{LOCALE_PREFIX}.week_of", date: text)
    end

    def week_tooltip?
      @bucket == :week && @form == :tooltip
    end

    def day_key(time, previous)
      return :day_with_year if previous.nil? && time.year != current_year
      return :day_with_year if previous && time.year != previous.year

      :day
    end

    def current_year
      Time.zone.now.year
    end

    def localize(time, key)
      I18n.l(time, format: I18n.t("#{LOCALE_PREFIX}.#{key}"))
    end
  end
end
