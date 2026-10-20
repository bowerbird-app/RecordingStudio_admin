# frozen_string_literal: true

module RecordingStudioAdmin
  module AdminActivityLogsSupport
    DATE_RANGE_PRESET_PARAM = :date_range_preset
    MAX_DATE_SERIES_BUCKETS = 1_000

    module_function

    def safe_like(value)
      "%#{ActiveRecord::Base.sanitize_sql_like(value.to_s)}%"
    end

    def date_series(relation, field: :created_at, bucket: :day)
      bucket = bucket.to_sym
      counts = grouped_bucket_counts(relation, Arel.sql(bucket_group_expression(field, bucket)))
      start_at, end_at = series_bounds(relation, field: field, counts: counts, bucket: bucket)

      fill_date_series(counts, start_at, end_at, bucket)
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

    def fill_date_series(counts, start_at, end_at, bucket)
      return mapped_bucket_counts(counts, bucket) unless start_at && end_at
      return mapped_bucket_counts(counts, bucket) if over_bucket_cap?(start_at, end_at, bucket)

      counts_by_key = index_bucket_counts(counts, bucket)
      each_series_bucket(start_at, end_at, bucket).map do |time|
        { x: bucket_label(time, bucket), y: counts_by_key[bucket_key(time, bucket)] || 0 }
      end
    end
    private_class_method :fill_date_series

    def grouped_bucket_counts(relation, sql_group_expression)
      chart_relation = relation.respond_to?(:except) ? relation.except(:order) : relation
      chart_relation.group(sql_group_expression).order(sql_group_expression).count
    end
    private_class_method :grouped_bucket_counts

    def mapped_bucket_counts(counts, bucket)
      counts.map { |date, count| { x: bucket_label(date, bucket), y: count } }
    end
    private_class_method :mapped_bucket_counts

    def index_bucket_counts(counts, bucket)
      counts.each_with_object({}) do |(value, count), indexed|
        indexed[bucket_key(value, bucket)] = count
      end
    end
    private_class_method :index_bucket_counts

    def series_bounds(relation, field:, counts:, bucket:)
      filter_start, filter_end = filter_time_bounds(relation, field)
      counted = counts.keys.map { |value| bucket_start(normalize_bucket_value(value), bucket) }

      start_at = filter_start || counted.min
      end_at = filter_end || counted.max
      return if start_at.nil? || end_at.nil?

      [bucket_start(start_at, bucket), bucket_start(end_at, bucket)]
    end
    private_class_method :series_bounds

    def filter_time_bounds(relation, field)
      min_time = nil
      max_time = nil

      each_time_bound(relation, field) do |kind, value, exclusive|
        time = normalize_bound_time(value)
        next unless time

        if kind == :min
          time += 1.second if exclusive
          min_time = [min_time, time].compact.max
        else
          time -= 1.second if exclusive
          max_time = [max_time, time].compact.min
        end
      end

      [min_time, max_time]
    end
    private_class_method :filter_time_bounds

    def each_time_bound(relation, field, &)
      return unless relation.respond_to?(:where_clause)

      clause = relation.where_clause
      return unless clause

      walk_bound_node(clause.ast, field, &) if clause.respond_to?(:ast)
    end
    private_class_method :each_time_bound

    def walk_bound_node(node, field, &block)
      return if node.nil?

      if node.is_a?(Arel::Nodes::And)
        Array(node.children).each { |child| walk_bound_node(child, field, &block) }
        return
      end

      if node.is_a?(Arel::Nodes::Grouping)
        walk_bound_node(node.expr, field, &block)
        return
      end

      yield_comparison_bound(node, field, &block)
    end
    private_class_method :walk_bound_node

    def yield_comparison_bound(node, field, &)
      case node
      when Arel::Nodes::GreaterThanOrEqual
        yield_field_bound(:min, node.left, node.right, false, field, &)
      when Arel::Nodes::GreaterThan
        yield_field_bound(:min, node.left, node.right, true, field, &)
      when Arel::Nodes::LessThanOrEqual
        yield_field_bound(:max, node.left, node.right, false, field, &)
      when Arel::Nodes::LessThan
        yield_field_bound(:max, node.left, node.right, true, field, &)
      when Arel::Nodes::Between
        yield_between_bounds(node, field, &)
      end
    end
    private_class_method :yield_comparison_bound

    def yield_between_bounds(node, field, &)
      lower, upper, exclusive_end = between_endpoints(node.right)
      yield_field_bound(:min, node.left, lower, false, field, &)
      yield_field_bound(:max, node.left, upper, exclusive_end, field, &)
    end
    private_class_method :yield_between_bounds

    def yield_field_bound(kind, left, right, exclusive, field)
      return unless attribute_matches_field?(left, field)

      yield kind, right, exclusive
    end
    private_class_method :yield_field_bound

    def between_endpoints(right)
      return [right.begin, right.end, right.exclude_end?] if right.is_a?(Range)

      children = right.respond_to?(:children) ? Array(right.children) : []
      [children[0], children[1], false]
    end
    private_class_method :between_endpoints

    def attribute_matches_field?(left, field)
      attribute_name = arel_attribute_name(left)
      field_name = field.to_s
      return false if attribute_name.blank?

      attribute_name == field_name || attribute_name.split(".").last == field_name.split(".").last
    end
    private_class_method :attribute_matches_field?

    def arel_attribute_name(left)
      return left.name.to_s if left.respond_to?(:name)
      return left.to_s if left.is_a?(Arel::Nodes::SqlLiteral)

      left.to_s
    end
    private_class_method :arel_attribute_name

    def normalize_bound_time(value)
      extracted = unwrap_arel_value(value)
      return if extracted.nil? || extracted == false

      normalize_bucket_value(extracted)
    rescue ArgumentError, TypeError
      nil
    end
    private_class_method :normalize_bound_time

    def unwrap_arel_value(value)
      return value.value_or_default if value.respond_to?(:value_or_default)
      return unwrap_arel_value(value.value) if value.respond_to?(:value) && !time_like?(value)

      value
    end
    private_class_method :unwrap_arel_value

    def time_like?(value)
      value.is_a?(Time) || value.is_a?(Date) || value.is_a?(ActiveSupport::TimeWithZone)
    end
    private_class_method :time_like?

    def each_series_bucket(start_at, end_at, bucket)
      return enum_for(:each_series_bucket, start_at, end_at, bucket) unless block_given?

      cursor = bucket_start(start_at, bucket)
      last = bucket_start(end_at, bucket)
      while cursor <= last
        yield cursor
        next_cursor = advance_bucket(cursor, bucket)
        break if next_cursor <= cursor

        cursor = next_cursor
      end
    end
    private_class_method :each_series_bucket

    def over_bucket_cap?(start_at, end_at, bucket)
      series_bucket_count(start_at, end_at, bucket) > MAX_DATE_SERIES_BUCKETS
    end
    private_class_method :over_bucket_cap?

    def series_bucket_count(start_at, end_at, bucket)
      first = bucket_start(start_at, bucket)
      last = bucket_start(end_at, bucket)
      return 0 if last < first

      bucket_span(first, last, bucket)
    end
    private_class_method :series_bucket_count

    def bucket_span(first, last, bucket)
      case bucket
      when :hour then ((last - first) / 1.hour).round + 1
      when :week then ((last.to_date - first.to_date).to_i / 7) + 1
      when :month then month_span(first, last)
      when :year then (last.year - first.year) + 1
      else
        (last.to_date - first.to_date).to_i + 1
      end
    end
    private_class_method :bucket_span

    def month_span(first, last)
      (((last.year * 12) + last.month) - ((first.year * 12) + first.month)) + 1
    end
    private_class_method :month_span

    def advance_bucket(time, bucket)
      case bucket
      when :hour
        time + 1.hour
      when :week
        (time + 1.week).beginning_of_week
      when :month
        (time + 1.month).beginning_of_month
      when :year
        (time + 1.year).beginning_of_year
      else
        time + 1.day
      end
    end
    private_class_method :advance_bucket

    def bucket_start(value, bucket)
      time = normalize_bucket_value(value)

      case bucket
      when :hour
        time.beginning_of_hour
      when :week
        time.beginning_of_week
      when :month
        time.beginning_of_month
      when :year
        time.beginning_of_year
      else
        time.beginning_of_day
      end
    end
    private_class_method :bucket_start

    def bucket_key(value, bucket)
      time = bucket_start(value, bucket)

      case bucket
      when :hour
        time.strftime("%Y-%m-%d %H")
      when :week
        time.strftime("%G-W%V")
      when :month
        time.strftime("%Y-%m")
      when :year
        time.strftime("%Y")
      else
        time.strftime("%Y-%m-%d")
      end
    end
    private_class_method :bucket_key

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
