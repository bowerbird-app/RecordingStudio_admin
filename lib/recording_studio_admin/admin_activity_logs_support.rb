# frozen_string_literal: true

module RecordingStudioAdmin
  module AdminActivityLogsSupport
    DATE_RANGE_PRESET_PARAM = :date_range_preset

    module_function

    def safe_like(value)
      "%#{ActiveRecord::Base.sanitize_sql_like(value.to_s)}%"
    end

    def date_series(relation, field: :created_at, bucket: :day)
      bucket = bucket.to_sym
      group_expression = bucket_group_expression(field, bucket)
      sql_group_expression = Arel.sql(group_expression)

      relation.group(sql_group_expression).order(sql_group_expression).count.map do |date, count|
        { x: bucket_label(date, bucket), y: count }
      end
    end

    def period_change_label(relation, field: :created_at, distinct_field: nil, current_period: 7.days.ago..,
                            previous_period: 14.days.ago...7.days.ago)
      current_count = period_count(relation, field: field, period: current_period, distinct_field: distinct_field)
      previous_count = period_count(relation, field: field, period: previous_period, distinct_field: distinct_field)

      percent_change_label(current_count: current_count, previous_count: previous_count)
    end

    def widget_preset_label(context, preset_key:, fallback:)
      context.widget_period_label(default_preset_key: preset_key) || fallback
    end

    def widget_preset_range(context, preset_key:)
      context.widget_time_range(default_preset_key: preset_key)
    end

    def widget_link_path(context, screen_key:, preset_key: nil, extra_params: {})
      query = extra_params.to_h
      if preset_key
        query = context.widget_filter_params(
          default_preset_key: preset_key,
          preset_param: DATE_RANGE_PRESET_PARAM
        ).merge(query)
      end

      safe_query = query.compact
      path = context.admin_screen_path(screen_key)
      return path if safe_query.empty?

      "#{path}?#{safe_query.to_query}"
    end

    def bucket_group_expression(field, bucket)
      case bucket
      when :hour
        "DATE_TRUNC('hour', #{field})"
      when :week
        "DATE_TRUNC('week', #{field})"
      when :month
        "DATE_TRUNC('month', #{field})"
      when :year
        "DATE_TRUNC('year', #{field})"
      else
        "DATE(#{field})"
      end
    end
    private_class_method :bucket_group_expression

    def bucket_label(value, bucket)
      timestamp = normalize_bucket_value(value)

      case bucket
      when :hour
        timestamp.strftime("%-l%P").strip
      when :week
        "Week of #{timestamp.strftime('%b %-d')}"
      when :month
        timestamp.strftime("%b")
      when :year
        timestamp.strftime("%Y")
      else
        timestamp.strftime("%b %-d")
      end
    end
    private_class_method :bucket_label

    def normalize_bucket_value(value)
      return value.in_time_zone if value.respond_to?(:in_time_zone)

      Time.zone.parse(value.to_s)
    end
    private_class_method :normalize_bucket_value

    def period_count(relation, field:, period:, distinct_field: nil)
      scoped_relation = relation.where(field => period)
      return scoped_relation.distinct.count(distinct_field) if distinct_field

      scoped_relation.count
    end
    private_class_method :period_count

    def percent_change_label(current_count:, previous_count:)
      return "0%" if current_count.zero? && previous_count.zero?
      return "+100%" if previous_count.zero? && current_count.positive?

      percent_change = ((current_count - previous_count) / previous_count.to_f) * 100
      format("%+.0f%%", percent_change)
    end
    private_class_method :percent_change_label
  end
end
