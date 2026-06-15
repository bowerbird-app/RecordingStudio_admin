# frozen_string_literal: true

RecordingStudioAdmin.configure do |config|
  config.authorization_method = :current_user
end

module AdminScreens
  class Base < RecordingStudioAdmin::Screen
    class << self
      def date_series(relation, field: :created_at, bucket: :day)
        bucket = bucket.to_sym
        group_expression = bucket_group_expression(field, bucket)

        sql_group_expression = Arel.sql(group_expression)

        relation.group(sql_group_expression).order(sql_group_expression).count.map do |date, count|
          { x: bucket_label(date, bucket), y: count }
        end
      end

      def distinct_date_series(relation, distinct_field:, field: :created_at, bucket: :day)
        bucket = bucket.to_sym
        group_expression = bucket_group_expression(field, bucket)

        sql_group_expression = Arel.sql(group_expression)
        distinct_expression = Arel.sql("COUNT(DISTINCT #{distinct_field})")

        relation.group(sql_group_expression).order(sql_group_expression).pluck(sql_group_expression, distinct_expression).map do |date, count|
          { x: bucket_label(date, bucket), y: count }
        end
      end

      def safe_like(value)
        "%#{ActiveRecord::Base.sanitize_sql_like(value.to_s)}%"
      end

      def period_change_label(relation, distinct_field: nil, current_period: 7.days.ago.., previous_period: 14.days.ago...7.days.ago)
        current_count = period_count(relation, period: current_period, distinct_field: distinct_field)
        previous_count = period_count(relation, period: previous_period, distinct_field: distinct_field)

        percent_change_label(current_count: current_count, previous_count: previous_count)
      end

      private

      def bucket_label(value, bucket)
        timestamp = normalize_bucket_value(value)

        case bucket
        when :hour
          timestamp.strftime("%-l%P").strip
        when :week
          "Week of #{timestamp.strftime("%b %-d")}"
        when :month
          timestamp.strftime("%b")
        when :year
          timestamp.strftime("%Y")
        else
          timestamp.strftime("%b %-d")
        end
      end

      def normalize_bucket_value(value)
        return value.in_time_zone if value.respond_to?(:in_time_zone)

        Time.zone.parse(value.to_s)
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

      def period_count(relation, period:, distinct_field: nil)
        scoped_relation = relation.where(created_at: period)
        return scoped_relation.distinct.count(distinct_field) if distinct_field

        scoped_relation.count
      end

      def percent_change_label(current_count:, previous_count:)
        return "0%" if current_count.zero? && previous_count.zero?
        return "+100%" if previous_count.zero? && current_count.positive?

        percent_change = ((current_count - previous_count) / previous_count.to_f) * 100
        format("%+.0f%%", percent_change)
      end
    end
  end

  class ApiRequests < Base
    key "api_requests"
    title "API requests"
    subtitle "Monitor API traffic, latency, and failures"
    query { |_context| ApiRequest.all }
    filter :date_range, field: :created_at, default: :last_30_days
    filter :group_by, values: %i[hour day week month year], default: :day
    filter :status, options: -> { ApiRequest.distinct.order(:status).pluck(:status) }

    chart do
      title "Requests over time"
      type :line
      series do |context|
        [ {
          name: "Requests",
          data: AdminScreens::Base.date_series(
            context.query_result.relation,
            bucket: context.filter_value(:group_by) || :day
          )
        } ]
      end
    end

    metric :total_count do
      label "Total requests"
      value { |context| context.query_result.count }
      change do |context|
        period = context.period_for
        if period&.start_date && period&.end_date
          span_days = (period.end_date - period.start_date).to_i + 1
          current_period = period.start_date.beginning_of_day..period.end_date.end_of_day
          previous_end = period.start_date - 1.day
          previous_start = previous_end - (span_days - 1).days
          previous_period = previous_start.beginning_of_day..previous_end.end_of_day

          AdminScreens::Base.period_change_label(
            ApiRequest.all,
            current_period: current_period,
            previous_period: previous_period
          )
        else
          AdminScreens::Base.period_change_label(ApiRequest.all)
        end
      end
      period_label { |context| context.period_label || "Last 30 days" }
      change_good_when :up
    end

    table do
      filter :search, apply: ->(relation, value, _context) { value.present? ? relation.where("path ILIKE ?", AdminScreens::Base.safe_like(value)) : relation }
      column :created_at
      column :method
      column :status, display: :badge, display_options: ->(_row, _context, value) do
        {
          text: value.to_s,
          size: :sm,
          style: case value.to_i
                 when 200..299 then :success
                 when 400..499 then :warning
                 when 500..599 then :danger
                 else :default
                 end
        }
      end
      column :path
      column :latency_ms, title: "Latency", tooltip: ->(row, _context) { "#{row.latency_ms}ms total request time" }
      paginate per_page: 25, mode: :infinite
    end

    widget :activity_last_24_hours do
      type :number
      title "API activity"
      description "Total API requests recorded during the last 24 hours."
      subtitle { |context| context.period_label(duration: 24.hours) || "Last 24 hours" }
      value { |_context| ApiRequest.where(created_at: 24.hours.ago..).count }
      link_to { |context| context.admin_screen_path("api_requests") }
    end

    widget :recent_request_paths do
      type :list
      title "Recent request paths"
      description "The three most recent API request paths seen by the dummy app."
      subtitle "Latest three requests"
      list_options divider: true
      metadata { |context| { period_label: context.period_label(duration: 24.hours) || "Last 24 hours" } }
      items do |_context|
        ApiRequest.order(created_at: :desc).limit(3).pluck(:path).map do |path|
          { text: path, icon: "document-text" }
        end
      end
      link_to { |context| context.admin_screen_path("api_requests") }
    end

    widget :api_activity_chart do
      type :chart
      title "API activity"
      description "Seven-day request volume with the current period total and percentage change."
      subtitle { |context| context.period_label(duration: 7.days) || "Last 7 days" }
      value { |_context| ApiRequest.where(created_at: 7.days.ago..).count }
      change { |_context| AdminScreens::Base.period_change_label(ApiRequest.all) }
      chart_type :line
      series do
        [ {
          name: "API activity",
          data: AdminScreens::Base.date_series(ApiRequest.where(created_at: 7.days.ago..), bucket: :day)
        } ]
      end
      chart_options { { height: 220 } }
      link_to { |context| context.admin_screen_path("api_requests") }
    end
  end

  class ApiErrors < Base
    key "api_errors"
    title "API errors"
    subtitle "Review API failures by class and status"
    query { |_context| ApiError.all }
    filter :date_range, field: :created_at, default: :last_30_days
    filter :group_by, values: %i[hour day week month year], default: :day

    chart do
      title "Errors over time"
      type :bar
      series do |context|
        [ {
          name: "Errors",
          data: AdminScreens::Base.date_series(
            context.query_result.relation,
            bucket: context.filter_value(:group_by) || :day
          )
        } ]
      end
    end

    table do
      filter :search, apply: ->(relation, value, _context) { value.present? ? relation.where("message ILIKE ?", AdminScreens::Base.safe_like(value)) : relation }
      column :created_at
      column :error_class
      column :status
      column :path
      column :message, sortable: false
      paginate per_page: 25
    end

    widget :recent_failures do
      type :number
      title "Recent failures"
      description "Total API errors recorded during the last 24 hours."
      subtitle { |context| context.period_label(duration: 24.hours) || "Last 24 hours" }
      value { |_context| ApiError.where(created_at: 24.hours.ago..).count }
      link_to { |context| context.admin_screen_path("api_errors") }
    end

    widget :recent_failures_chart do
      type :chart
      title "Recent failures"
      description "Seven-day API error trend with the current period total and percentage change."
      subtitle { |context| context.period_label(duration: 7.days) || "Last 7 days" }
      value { |_context| ApiError.where(created_at: 7.days.ago..).count }
      change { |_context| AdminScreens::Base.period_change_label(ApiError.all) }
      chart_type :bar
      series do
        [ {
          name: "Recent failures",
          data: AdminScreens::Base.date_series(ApiError.where(created_at: 7.days.ago..), bucket: :day)
        } ]
      end
      chart_options { { height: 220 } }
      link_to { |context| context.admin_screen_path("api_errors") }
    end
  end

  class Users < Base
    key "users"
    title "Users"
    subtitle "Review user activity and access signals"
    query { |_context| UserActivity.all }
    filter :date_range, field: :created_at, default: :last_30_days
    filter :status, options: -> { UserActivity.distinct.order(:status).pluck(:status) }

    chart do
      title "Activity over time"
      type :line
      series do |context|
        [ {
          name: "Activities",
          data: AdminScreens::Base.date_series(
            context.query_result.relation,
            bucket: context.filter_value(:group_by) || :day
          )
        } ]
      end
    end

    table do
      filter :search, apply: ->(relation, value, _context) { value.present? ? relation.where("email ILIKE ?", AdminScreens::Base.safe_like(value)) : relation }
      column :created_at
      column :email
      column :action
      column :status
      paginate per_page: 25
    end

    widget :active_users do
      type :number
      title "Active users"
      description "Distinct users seen during the last 24 hours."
      subtitle { |context| context.period_label(duration: 24.hours) || "Last 24 hours" }
      value { |_context| UserActivity.where(created_at: 24.hours.ago..).distinct.count(:email) }
      link_to { |context| context.admin_screen_path("users") }
    end

    widget :active_users_chart do
      type :chart
      title "Active users"
      description "Daily unique users across the last seven days, plus the current period delta."
      subtitle "Daily unique users"
      metadata { |context| { period_label: context.period_label(duration: 7.days) || "Last 7 days" } }
      value { |_context| UserActivity.where(created_at: 7.days.ago..).distinct.count(:email) }
      change { |_context| AdminScreens::Base.period_change_label(UserActivity.all, distinct_field: :email) }
      chart_type :line
      series do
        [ {
          name: "Active users",
          data: AdminScreens::Base.distinct_date_series(UserActivity.where(created_at: 7.days.ago..), distinct_field: :email, bucket: :day)
        } ]
      end
      chart_options { { height: 220 } }
      link_to { |context| context.admin_screen_path("users") }
    end

    widget :most_recent_users do
      type :list
      title "Most recent users"
      description "The five most recent users seen by the dummy app."
      subtitle "Latest five users"
      list_options divider: true, hover: true
      items do |_context|
        UserActivity.order(created_at: :desc).limit(5).pluck(:email).map do |email|
          {
            text: email,
            href: "/users/#{email.parameterize}"
          }
        end
      end
      link_to { |context| context.admin_screen_path("users") }
    end
  end

  class BackgroundJobs < Base
    key "background_jobs"
    title "Background jobs"
    subtitle "Monitor queue throughput and job failures"
    query { |_context| BackgroundJobRun.all }
    filter :date_range, field: :created_at, default: :last_30_days
    filter :queue, options: -> { BackgroundJobRun.distinct.order(:queue).pluck(:queue) }

    chart do
      title "Jobs over time"
      type :bar
      series do |context|
        [ {
          name: "Jobs",
          data: AdminScreens::Base.date_series(
            context.query_result.relation,
            bucket: context.filter_value(:group_by) || :day
          )
        } ]
      end
    end

    table do
      filter :search, apply: ->(relation, value, _context) { value.present? ? relation.where("job_class ILIKE ?", AdminScreens::Base.safe_like(value)) : relation }
      column :created_at
      column :job_class
      column :queue
      column :status
      column :duration_ms, title: "Duration", tooltip: ->(row, _context) { "#{row.duration_ms}ms runtime" }
      paginate per_page: 25
    end

    widget :job_throughput do
      type :number
      title "Job throughput"
      description "Background jobs processed during the last 24 hours."
      subtitle { |context| context.period_label(duration: 24.hours) || "Last 24 hours" }
      value { |_context| BackgroundJobRun.where(created_at: 24.hours.ago..).count }
      link_to { |context| context.admin_screen_path("background_jobs") }
    end

    widget :job_throughput_chart do
      type :chart
      title "Job throughput"
      description "Seven-day background job volume with the current period total and percentage change."
      subtitle { |context| context.period_label(duration: 7.days) || "Last 7 days" }
      value { |_context| BackgroundJobRun.where(created_at: 7.days.ago..).count }
      change { |_context| AdminScreens::Base.period_change_label(BackgroundJobRun.all) }
      chart_type :bar
      series do
        [ {
          name: "Job throughput",
          data: AdminScreens::Base.date_series(BackgroundJobRun.where(created_at: 7.days.ago..), bucket: :day)
        } ]
      end
      chart_options { { height: 220 } }
      link_to { |context| context.admin_screen_path("background_jobs") }
    end
  end

  class RootSection < RecordingStudioAdmin::Section
    key "root"
    title "Admin summary"
    subtitle "Monitor API traffic, users, jobs, and failures"

    recordable "AdminSummarySection",
               find_or_create_by: -> { { key: "root", name: "Admin summary" } },
               parent: -> { AdminRoot.find_or_create_by!(name: "Admin") }

    link :requests, text: "View API requests", url: ->(context) { context.admin_screen_path("api_requests") }, style: :secondary
    link :errors, text: "View API errors", url: ->(context) { context.admin_screen_path("api_errors") }, style: :secondary
    link :users, text: "View users", url: ->(context) { context.admin_screen_path("users") }, style: :secondary
    link :jobs, text: "View background jobs", url: ->(context) { context.admin_screen_path("background_jobs") }, style: :secondary

    widget "api_requests.widgets.activity_last_24_hours", view_variant: :chip
    widget "api_requests.widgets.recent_request_paths"
    widget "api_requests.widgets.api_activity_chart"
    widget "api_errors.widgets.recent_failures", view_variant: :chip
    widget "api_errors.widgets.recent_failures_chart"
    widget "users.widgets.active_users", view_variant: :chip
    widget "users.widgets.active_users_chart"
    widget "users.widgets.most_recent_users"
    widget "background_jobs.widgets.job_throughput", view_variant: :chip
    widget "background_jobs.widgets.job_throughput_chart"
  end
end

Rails.application.config.to_prepare do
  RecordingStudioAdmin.register_screen(AdminScreens::ApiRequests)
  RecordingStudioAdmin.register_screen(AdminScreens::ApiErrors)
  RecordingStudioAdmin.register_screen(AdminScreens::Users)
  RecordingStudioAdmin.register_screen(AdminScreens::BackgroundJobs)
  RecordingStudioAdmin.register_section(AdminScreens::RootSection)
end
