# frozen_string_literal: true

module RecordingStudioAdmin
  # Reads day and month labels produced by DateAxisLabels.
  class HorizontalBarDateParser
    DAY_LABEL = /\A(?<month>[A-Za-z]{3,}) (?<day>\d{1,2})(?: (?<year>\d{4}))?\z/
    MONTH_LABEL = /\A(?<month>[A-Za-z]{3,})(?: (?<year>\d{4}))?\z/

    def self.parse(series)
      new(series).parse
    end

    def initialize(series)
      @series = series
    end

    def parse
      entries = series_entries
      return if entries.empty?

      days = dated_entries(entries, :day)
      return packed(days, :day) if dated?(days)

      months = dated_entries(entries, :month)
      return unless dated?(months)

      packed(months, :month)
    end

    private

    def series_entries
      case @series
      when Hash then [@series]
      when Array then @series
      else []
      end
    end

    def dated_entries(entries, kind)
      entries.map { |entry| dated_entry(entry, kind) }
    end

    def dated?(entries)
      entries.is_a?(Array) && entries.none?(&:nil?) && entries.any? { |entry| entry[:points] }
    end

    def packed(entries, kind)
      { kind: kind, entries: entries, count: entries.map { |entry| Array(entry[:points]).size }.max }
    end

    def dated_entry(entry, kind)
      return { entry: entry } unless entry.is_a?(Hash)

      key = data_key(entry)
      points = key ? entry[key] : nil
      return { entry: entry } unless points.is_a?(Array) && points.any?

      dated = dated_points(points, kind)
      return unless dated

      { entry: entry, key: key, points: dated }
    end

    def dated_points(points, kind)
      year = nil
      dated = []
      points.each do |point|
        date = point_date(point, kind, year)
        dated = append_dated_point(dated, point, date)
        year = date&.year
        break unless date
      end
      dated
    end

    def append_dated_point(dated, point, date)
      return unless date

      dated << { date: date, y: point_y(point), point: point }
    end

    def point_date(point, kind, year)
      label = point_label(point)
      return unless label

      match = label.match(kind == :day ? DAY_LABEL : MONTH_LABEL)
      return unless match

      day = kind == :day ? match[:day].to_i : 1
      build_date(match[:month], day, match[:year]&.to_i || year)
    end

    def point_label(point)
      return unless point.is_a?(Hash)

      text = point[:x] || point["x"]
      text.is_a?(String) ? text.delete("\u200b") : nil
    end

    def point_y(point)
      value = point[:y] || point["y"]
      value.is_a?(Numeric) ? value : 0
    end

    def build_date(month_name, day, year)
      month = month_index(month_name)
      return unless month

      Date.new(year || Time.zone.now.year, month, day)
    rescue ArgumentError
      nil
    end

    def month_index(name)
      names = Array(I18n.t("date.abbr_month_names", default: Date::ABBR_MONTHNAMES))
      names.index { |entry| entry.to_s.casecmp?(name) }
    end

    def data_key(entry)
      return :data if entry.key?(:data)
      return "data" if entry.key?("data")

      nil
    end
  end

  # Groups a horizontal bar date series so category labels fit the card.
  class HorizontalBarBuckets
    MAX_ROWS = 12
    COARSER_BUCKETS = %i[week month year].freeze

    def self.group(series)
      new(series).group
    end

    def initialize(series)
      @series = series
    end

    def group
      parsed = HorizontalBarDateParser.parse(@series)
      return @series if parsed.nil? || parsed.fetch(:count) <= MAX_ROWS

      rebuild(parsed.fetch(:entries), chosen_bucket(parsed))
    end

    private

    def chosen_bucket(parsed)
      return :year if parsed.fetch(:kind) == :month

      dates = dates_for(parsed.fetch(:entries))
      COARSER_BUCKETS.find { |bucket| unique_count(dates, bucket) <= MAX_ROWS } || :year
    end

    def dates_for(entries)
      entries.flat_map { |entry| Array(entry[:points]).map { |point| point[:date] } }
    end

    def unique_count(dates, bucket)
      dates.map { |date| bucket_stamp(date, bucket) }.uniq.size
    end

    def bucket_stamp(date, bucket)
      case bucket
      when :week then date.beginning_of_week.iso8601
      when :month then date.strftime("%Y-%m")
      else date.year.to_s
      end
    end

    def rebuild(entries, bucket)
      stamps = dates_for(entries).map { |date| bucket_stamp(date, bucket) }.uniq.sort
      labels = DateAxisLabels.call(stamps.map { |stamp| stamp_time(stamp, bucket) }, bucket: bucket)
      grouped = entries.map { |entry| replace_points(entry, stamps, labels, bucket) }
      @series.is_a?(Hash) ? grouped.first : grouped
    end

    def stamp_time(stamp, bucket)
      case bucket
      when :month then month_time(stamp)
      when :year then Time.zone.local(stamp.to_i, 1, 1)
      else day_time(Date.iso8601(stamp))
      end
    end

    def month_time(stamp)
      year, month = stamp.split("-").map(&:to_i)
      Time.zone.local(year, month, 1)
    end

    def day_time(date)
      Time.zone.local(date.year, date.month, date.day)
    end

    def replace_points(entry, stamps, labels, bucket)
      return entry.fetch(:entry) unless entry[:points]

      entry.fetch(:entry).merge(entry.fetch(:key) => grouped_points(entry, stamps, labels, bucket))
    end

    def grouped_points(entry, stamps, labels, bucket)
      sums = stamp_sums(entry.fetch(:points), bucket)
      keys = axis_keys(entry.fetch(:points).first.fetch(:point))
      stamps.each_with_index.map { |stamp, index| { keys[0] => labels.fetch(index), keys[1] => sums[stamp] } }
    end

    def stamp_sums(points, bucket)
      points.each_with_object(Hash.new(0)) do |point, sums|
        sums[bucket_stamp(point.fetch(:date), bucket)] += point.fetch(:y)
      end
    end

    def axis_keys(point)
      point.key?(:x) || point.key?(:y) ? %i[x y] : %w[x y]
    end
  end
end
