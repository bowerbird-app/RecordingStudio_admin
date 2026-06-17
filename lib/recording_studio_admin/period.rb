# frozen_string_literal: true

module RecordingStudioAdmin
  class Period
    PRESET_PATTERN = /\Alast_(\d+)_(hours|days|weeks|months|years)\z/
    QUICK_PRESET_LABELS = {
      today: "Today",
      yesterday: "Yesterday",
      last_3_days: "Last 3 days",
      this_week: "This week",
      last_week: "Last week",
      this_month: "This month",
      last_month: "Last month",
      this_year: "This year",
      last_year: "Last year"
    }.freeze

    attr_reader :amount, :unit, :start_date, :end_date

    def initialize(amount:, unit:, start_date: nil, end_date: nil, explicit_label: nil)
      @amount = amount.to_i
      @unit = unit.to_sym
      @start_date = start_date
      @end_date = end_date
      @explicit_label = explicit_label
    end

    def label
      return @explicit_label if @explicit_label

      "Last #{amount} #{unit_word}"
    end

    class << self
      def from_duration(duration, reference_time: current_time)
        amount, unit = extract_duration(duration)
        return unless amount && unit

        end_date = reference_time.to_date
        start_date = calculate_start_date(end_date, amount, unit)
        new(amount: amount, unit: unit, start_date: start_date, end_date: end_date)
      end

      def from_date_range(start_date:, end_date:, preset_key: nil, reference_date: current_date)
        quick_preset_key = normalize_quick_preset_key(preset_key) || infer_quick_preset_key(
          start_date,
          end_date,
          reference_date
        )
        if quick_preset_key
          span_days = (end_date - start_date).to_i + 1
          return new(
            amount: span_days,
            unit: :day,
            start_date: start_date,
            end_date: end_date,
            explicit_label: QUICK_PRESET_LABELS.fetch(quick_preset_key)
          )
        end

        if preset_key
          amount, unit = parse_preset_key(preset_key)
          return new(amount: amount, unit: unit, start_date: start_date, end_date: end_date) if amount && unit
        end

        return unless start_date && end_date

        span_days = (end_date - start_date).to_i + 1
        if end_date == reference_date
          if span_days >= 14 && (span_days % 7).zero?
            return new(amount: span_days / 7, unit: :week, start_date: start_date, end_date: end_date)
          end

          return new(amount: span_days, unit: :day, start_date: start_date, end_date: end_date)
        end

        label = "#{start_date.strftime('%b %-d')} to #{end_date.strftime('%b %-d')}"
        new(amount: span_days, unit: :day, start_date: start_date, end_date: end_date, explicit_label: label)
      end

      private

      def extract_duration(duration)
        return unless duration.respond_to?(:parts)

        parts = duration.parts
        return if parts.nil? || parts.size != 1

        unit, amount = parts.first
        normalized_unit = normalize_unit(unit)
        return unless normalized_unit

        [amount.to_i, normalized_unit]
      end

      def parse_preset_key(key)
        match = key.to_s.match(PRESET_PATTERN)
        return unless match

        amount = match[1].to_i
        unit = normalize_unit(match[2])
        [amount, unit]
      end

      def normalize_quick_preset_key(key)
        normalized = key.to_s.downcase.strip.to_sym
        return unless QUICK_PRESET_LABELS.key?(normalized)

        normalized
      end

      def infer_quick_preset_key(start_date, end_date, reference_date)
        return unless start_date && end_date && reference_date

        return :today if start_date == reference_date && end_date == reference_date

        yesterday = reference_date - 1
        return :yesterday if start_date == yesterday && end_date == yesterday
        return :last_3_days if start_date == (reference_date - 2) && end_date == reference_date

        this_week_start = start_of_week(reference_date)
        return :this_week if start_date == this_week_start && end_date == reference_date

        last_week_end = this_week_start - 1
        last_week_start = start_of_week(last_week_end)
        return :last_week if start_date == last_week_start && end_date == last_week_end

        this_month_start = Date.new(reference_date.year, reference_date.month, 1)
        return :this_month if start_date == this_month_start && end_date == reference_date

        last_month_reference = reference_date << 1
        last_month_start = Date.new(last_month_reference.year, last_month_reference.month, 1)
        last_month_end = this_month_start - 1
        return :last_month if start_date == last_month_start && end_date == last_month_end

        this_year_start = Date.new(reference_date.year, 1, 1)
        return :this_year if start_date == this_year_start && end_date == reference_date

        last_year_start = Date.new(reference_date.year - 1, 1, 1)
        last_year_end = Date.new(reference_date.year - 1, 12, 31)
        return :last_year if start_date == last_year_start && end_date == last_year_end

        nil
      end

      def start_of_week(date)
        date - ((date.wday + 6) % 7)
      end

      def normalize_unit(unit)
        value = unit.to_s
        value = value.delete_suffix("s")
        return unless %w[hour day week month year].include?(value)

        value.to_sym
      end

      def calculate_start_date(end_date, amount, unit)
        case unit
        when :week
          end_date - (amount * 7)
        when :month
          end_date << amount
        when :year
          end_date << (amount * 12)
        else
          end_date - amount
        end
      end

      def current_date
        if defined?(Date) && Date.respond_to?(:current)
          Date.current
        elsif defined?(Date)
          Date.today
        else
          current_time.to_date
        end
      end

      def current_time
        if defined?(Time) && Time.respond_to?(:zone) && Time.zone
          Time.zone.now
        else
          Time.now
        end
      end
    end

    private

    def unit_word
      amount == 1 ? unit.to_s : "#{unit}s"
    end
  end
end
