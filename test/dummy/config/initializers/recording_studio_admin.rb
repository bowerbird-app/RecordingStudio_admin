# frozen_string_literal: true

RecordingStudioAdmin.configure do |config|
  config.access_recording_resolver = lambda do |_context|
    admin_root = AdminRoot.find_by(name: "Admin")
    next unless admin_root

    RecordingStudio::Recording.find_by(recordable: admin_root, trashed_at: nil)
  end
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
    icon :document_text
    navigation_parent "root"
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

    summary do
      label "Total requests"
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
      action :filter_path,
        text: "Filter path",
        icon: "funnel",
        url: ->(row, context) { "#{context.admin_screen_path("api_requests")}?#{ { search: row.path }.to_query }" }
      action :view_errors,
        text: "View errors",
        icon: "exclamation-triangle",
        url: ->(row, context) { "#{context.admin_screen_path("api_errors")}?#{ { search: row.path }.to_query }" },
        visible_if: ->(row, _context) { row.status.to_i >= 400 }
      paginate per_page: 25, mode: :infinite
    end

    widget :api_activity do
      type :chart
      title "API activity"
      description "Seven-day request volume with the current period total and percentage change."
      metadata { |context| { period_label: context.widget_period_label(default_duration: 7.days) || "Last 7 days" } }
      value { |context| ApiRequest.where(created_at: context.widget_time_range(default_duration: 7.days)).count }
      change { |_context| AdminScreens::Base.period_change_label(ApiRequest.all) }
      chart_type :area
      series do
        range = _1.widget_time_range(default_duration: 7.days)
        [ {
          name: "API activity",
          data: AdminScreens::Base.date_series(ApiRequest.where(created_at: range), bucket: _1.widget_group_by(default: :day))
        } ]
      end
      chart_options { { height: 220 } }
      link_to { |context| context.admin_screen_path("api_requests") }
    end

    widget :monthly_api_usage do
      type :progress
      title "Monthly API usage"
      subtitle "Requests used against the monthly plan"
      description "Current calendar-month API usage against an example monthly quota."
      metadata do
        monthly_quota = 10_000
        current_usage = ApiRequest.where(created_at: Time.current.beginning_of_month..Time.current).count

        {
          period_label: Time.current.strftime("%B %Y"),
          progress_value: current_usage,
          progress_max: monthly_quota,
          progress_label: "#{current_usage} / #{monthly_quota} requests",
          progress_variant: case current_usage.to_f / monthly_quota
                            when 0.0...0.75 then :success
                            when 0.75...0.9 then :warning
                            else :danger
                            end
        }
      end
      link_to { |context| context.admin_screen_path("api_requests") }
    end
  end

  class ApiErrors < Base
    key "api_errors"
    icon :exclamation_triangle
    navigation_parent "root"
    title "API errors"
    subtitle "Review API failures by class and status"
    query { |_context| ApiError.all }
    filter :date_range, field: :created_at, default: :last_30_days
    filter :group_by, values: %i[hour day week month year], default: :day

    summary do
      label "Total errors"
      change_good_when :down
    end

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
      filter :search, apply: lambda { |relation, value, _context|
        next relation unless value.present?

        q = AdminScreens::Base.safe_like(value)
        relation.where("message ILIKE :q OR path ILIKE :q OR error_class ILIKE :q", q: q)
      }
      column :created_at
      column :error_class
      column :status
      column :path
      column :message, sortable: false
      action :view_requests,
        text: "View requests",
        icon: "magnifying-glass",
        url: ->(row, context) { "#{context.admin_screen_path("api_requests")}?#{ { search: row.path }.to_query }" }
      action :similar_errors,
        text: "Similar errors",
        icon: "funnel",
        url: ->(row, context) { "#{context.admin_screen_path("api_errors")}?#{ { search: row.error_class }.to_query }" }
      paginate per_page: 25
    end

    widget :recent_failures do
      type :chart
      title "Recent failures"
      description "Seven-day API error trend with the current period total and percentage change."
      metadata { |context| { period_label: context.widget_period_label(default_duration: 7.days) || "Last 7 days" } }
      value { |context| ApiError.where(created_at: context.widget_time_range(default_duration: 7.days)).count }
      change { |_context| AdminScreens::Base.period_change_label(ApiError.all) }
      chart_type :bar
      series do
        range = _1.widget_time_range(default_duration: 7.days)
        [ {
          name: "Recent failures",
          data: AdminScreens::Base.date_series(ApiError.where(created_at: range), bucket: _1.widget_group_by(default: :day))
        } ]
      end
      chart_options { { height: 220 } }
      link_to { |context| context.admin_screen_path("api_errors") }
    end
  end

  class Users < Base
    key "users"
    icon :user_group
    navigation_parent "root"
    title "Users"
    subtitle "Review user activity and access signals"
    query { |_context| UserActivity.all }
    filter :date_range, field: :created_at, default: :last_30_days
    filter :group_by, values: %i[hour day week month year], default: :day
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

    summary do
      label "Total activities"
      change_good_when :up
    end

    table do
      filter :search, apply: ->(relation, value, _context) { value.present? ? relation.where("email ILIKE ?", AdminScreens::Base.safe_like(value)) : relation }
      column :created_at
      column :email
      column :action
      column :status
          action :view_sign_ins,
            text: "View sign-ins",
            icon: "arrow-right-end-on-rectangle",
            url: ->(row, context) { "#{context.admin_screen_path("user_sign_ins")}?#{ { search: row.email }.to_query }" }
          action :review_queue,
            text: "Review queue",
            icon: "clipboard-document-check",
            url: ->(row, context) { "#{context.admin_screen_path("user_reviews")}?#{ { search: row.email }.to_query }" },
            visible_if: ->(row, _context) { row.status == "review" }
          action :delete_activity,
            text: "Delete activity",
            icon: "trash",
            url: ->(row, _context) { "/admin/user_activities/#{row.id}" },
            method: :delete,
            confirm: ->(row, _context) { "Delete activity for #{row.email}?" },
            destructive: true
      paginate per_page: 25
    end

    widget :active_users do
      type :chart
      title "Active users"
      description "Daily unique users across the last seven days, plus the current period delta."
      subtitle "Daily unique users"
      metadata { |context| { period_label: context.widget_period_label(default_duration: 7.days) || "Last 7 days" } }
      value { |context| UserActivity.where(created_at: context.widget_time_range(default_duration: 7.days)).distinct.count(:email) }
      change { |_context| AdminScreens::Base.period_change_label(UserActivity.all, distinct_field: :email) }
      chart_type :line
      series do
        range = _1.widget_time_range(default_duration: 7.days)
        [ {
          name: "Active users",
          data: AdminScreens::Base.distinct_date_series(
            UserActivity.where(created_at: range),
            distinct_field: :email,
            bucket: _1.widget_group_by(default: :day)
          )
        } ]
      end
      chart_options { { height: 220 } }
      link_to { |context| context.admin_screen_path("users") }
    end

    widget :review_completion do
      type :progress
      title "Review completion"
      subtitle "Resolved review backlog"
      link_label "User reviews"
      metadata do |context|
        range = context.widget_time_range(default_duration: 14.days)
        scope = UserActivity.where(created_at: range)
        total = scope.count
        completed = scope.where.not(status: "review").count

        {
          period_label: context.widget_period_label(default_duration: 14.days) || "Last 14 days",
          progress_value: completed,
          progress_max: [total, 1].max,
          progress_label: "#{completed} / #{total} reviewed",
          progress_variant: completed == total ? :success : :warning
        }
      end
      link_to { |context| context.admin_screen_path("user_reviews") }
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
            icon: :user_circle,
            text: email,
            href: "/users/#{email.parameterize}"
          }
        end
      end
      link_to { |context| context.admin_screen_path("users") }
    end
  end

  class UserSignIns < Base
    key "user_sign_ins"
    icon :arrow_right_end_on_rectangle
    navigation_parent "users"
    title "User sign-ins"
    subtitle "Track sign-in volume and recent access events"
    query { |_context| UserActivity.where(action: "signed_in") }
    filter :date_range, field: :created_at, default: :last_30_days
    filter :group_by, values: %i[hour day week month year], default: :day
    filter :status, options: -> { UserActivity.where(action: "signed_in").distinct.order(:status).pluck(:status) }

    chart do
      title "Sign-ins over time"
      type :area
      series do |context|
        [ {
          name: "Sign-ins",
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
      column :status
      action :view_activity,
        text: "View activity",
        icon: "user-circle",
        url: ->(row, context) { "#{context.admin_screen_path("users")}?#{ { search: row.email }.to_query }" }
      action :review_queue,
        text: "Review queue",
        icon: "clipboard-document-check",
        url: ->(row, context) { "#{context.admin_screen_path("user_reviews")}?#{ { search: row.email }.to_query }" },
        visible_if: ->(row, _context) { row.status == "review" }
      action :delete_sign_in,
        text: "Delete sign-in",
        icon: "trash",
        url: ->(row, _context) { "/admin/user_activities/#{row.id}" },
        method: :delete,
        confirm: ->(row, _context) { "Delete sign-in activity for #{row.email}?" },
        destructive: true
      paginate per_page: 25
    end

    widget :sign_in_activity do
      type :chart
      title "Sign-in activity"
      description "Seven-day sign-in volume with the current period total and percentage change."
      metadata { |context| { period_label: context.widget_period_label(default_duration: 7.days) || "Last 7 days" } }
      value { |context| UserActivity.where(action: "signed_in", created_at: context.widget_time_range(default_duration: 7.days)).count }
      change { |_context| AdminScreens::Base.period_change_label(UserActivity.where(action: "signed_in")) }
      chart_type :area
      series do
        range = _1.widget_time_range(default_duration: 7.days)
        [ {
          name: "Sign-in activity",
          data: AdminScreens::Base.date_series(
            UserActivity.where(action: "signed_in", created_at: range),
            bucket: _1.widget_group_by(default: :day)
          )
        } ]
      end
      chart_options { { height: 220 } }
      link_to { |context| context.admin_screen_path("user_sign_ins") }
    end
  end

  class UserReviews < Base
    key "user_reviews"
    icon :clipboard_document_check
    navigation_parent "users"
    title "User reviews"
    subtitle "Inspect user activity that still needs review"
    query { |_context| UserActivity.where(status: "review") }
    filter :date_range, field: :created_at, default: :last_30_days
    filter :group_by, values: %i[hour day week month year], default: :day
    filter :action, options: -> { UserActivity.where(status: "review").distinct.order(:action).pluck(:action) }

    chart do
      title "Review activity"
      type :bar
      series do |context|
        [ {
          name: "Review queue",
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
      action :view_activity,
        text: "View activity",
        icon: "user-circle",
        url: ->(row, context) { "#{context.admin_screen_path("users")}?#{ { search: row.email }.to_query }" }
      action :view_sign_ins,
        text: "View sign-ins",
        icon: "arrow-right-end-on-rectangle",
        url: ->(row, context) { "#{context.admin_screen_path("user_sign_ins")}?#{ { search: row.email }.to_query }" }
      action :delete_review,
        text: "Delete review",
        icon: "trash",
        url: ->(row, _context) { "/admin/user_activities/#{row.id}" },
        method: :delete,
        confirm: ->(row, _context) { "Delete review activity for #{row.email}?" },
        destructive: true
      paginate per_page: 25
    end

    widget :review_volume do
      type :chart
      title "Review queue"
      description "Review-needed user activity across the last fourteen days."
      metadata { |context| { period_label: context.widget_period_label(default_duration: 14.days) || "Last 14 days" } }
      value { |context| UserActivity.where(status: "review", created_at: context.widget_time_range(default_duration: 14.days)).count }
      change { |_context| AdminScreens::Base.period_change_label(UserActivity.where(status: "review")) }
      chart_type :bar
      series do
        range = _1.widget_time_range(default_duration: 14.days)
        [ {
          name: "Review queue",
          data: AdminScreens::Base.date_series(
            UserActivity.where(status: "review", created_at: range),
            bucket: _1.widget_group_by(default: :day)
          )
        } ]
      end
      chart_options { { height: 220 } }
      link_to { |context| context.admin_screen_path("user_reviews") }
    end
  end

  class UserInvitations < Base
    key "user_invitations"
    icon :user_plus
    navigation_parent "users"
    title "User invitations"
    subtitle "Monitor invitation activity and newly invited users"
    query { |_context| UserActivity.where(action: "invited_user") }
    filter :date_range, field: :created_at, default: :last_30_days
    filter :group_by, values: %i[hour day week month year], default: :day
    filter :status, options: -> { UserActivity.where(action: "invited_user").distinct.order(:status).pluck(:status) }

    chart do
      title "Invitations over time"
      type :line
      series do |context|
        [ {
          name: "Invitations",
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
      column :status
      action :view_activity,
        text: "View activity",
        icon: "user-circle",
        url: ->(row, context) { "#{context.admin_screen_path("users")}?#{ { search: row.email }.to_query }" }
      action :view_sign_ins,
        text: "View sign-ins",
        icon: "arrow-right-end-on-rectangle",
        url: ->(row, context) { "#{context.admin_screen_path("user_sign_ins")}?#{ { search: row.email }.to_query }" }
      action :delete_invitation,
        text: "Delete invitation",
        icon: "trash",
        url: ->(row, _context) { "/admin/user_activities/#{row.id}" },
        method: :delete,
        confirm: ->(row, _context) { "Delete invitation activity for #{row.email}?" },
        destructive: true
      paginate per_page: 25
    end

    widget :recent_invites do
      type :list
      title "Recent invites"
      description "Recently invited users captured by the dummy app."
      subtitle "Latest invitations"
      list_options divider: true, hover: true
      items do |_context|
        UserActivity.where(action: "invited_user").order(created_at: :desc).limit(5).pluck(:email).map do |email|
          {
            icon: :user_plus,
            text: email,
            href: "/users/#{email.parameterize}"
          }
        end
      end
      link_to { |context| context.admin_screen_path("user_invitations") }
    end
  end

  class BackgroundJobs < Base
    key "background_jobs"
    icon :bolt
    navigation_parent "root"
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
      action :view_job_class,
        text: "View job class",
        icon: "magnifying-glass",
        url: ->(row, context) { "#{context.admin_screen_path("background_jobs")}?#{ { search: row.job_class }.to_query }" }
      action :filter_queue,
        text: "Filter queue",
        icon: "funnel",
        url: ->(row, context) { "#{context.admin_screen_path("background_jobs")}?#{ { queue: row.queue }.to_query }" }
      paginate per_page: 25
    end

    widget :job_throughput do
      type :chart
      title "Job throughput"
      description "Seven-day background job volume with the current period total and percentage change."
      metadata { |context| { period_label: context.widget_period_label(default_duration: 7.days) || "Last 7 days" } }
      value { |context| BackgroundJobRun.where(created_at: context.widget_time_range(default_duration: 7.days)).count }
      change { |_context| AdminScreens::Base.period_change_label(BackgroundJobRun.all) }
      chart_type :bar
      series do
        range = _1.widget_time_range(default_duration: 7.days)
        [ {
          name: "Job throughput",
          data: AdminScreens::Base.date_series(BackgroundJobRun.where(created_at: range), bucket: _1.widget_group_by(default: :day))
        } ]
      end
      chart_options { { height: 220 } }
      link_to { |context| context.admin_screen_path("background_jobs") }
    end
  end

  class MostCommonErrors < Base
    class << self
      def top_error_breakdown(relation, limit: 5)
        relation
          .group(:error_class)
          .order(Arel.sql("COUNT(*) DESC"))
          .limit(limit)
          .count
          .map { |error_class, count| { label: error_class, value: count } }
      end

      def grouped_error_counts(relation, limit: nil)
        scoped = relation
        scoped = scoped.limit(limit) if limit

        scoped.map do |row|
          {
            label: row.error_class,
            value: row.error_count.to_i
          }
        end
      end
    end

    key "most_common_errors"
    icon :chart_pie
    navigation_parent "root"
    title "Most common errors"
    subtitle "Track the highest-volume API error classes"
    query do |_context|
      ApiError
        .where.not(error_class: [nil, ""])
        .select("error_class, COUNT(*) AS error_count")
        .group(:error_class)
    end
    filter :date_range, field: :created_at, default: :last_30_days

    chart do
      title "Top error classes"
      subtitle "By total occurrences in the selected date range"
      type :pie
      series do |context|
        AdminScreens::MostCommonErrors.grouped_error_counts(context.query_result.relation.order(Arel.sql("error_count DESC")),
                                                            limit: 5).map do |entry|
          entry[:value]
        end
      end
      options do |context|
        breakdown = AdminScreens::MostCommonErrors.grouped_error_counts(
          context.query_result.relation.order(Arel.sql("error_count DESC")),
          limit: 5
        )
        {
          labels: breakdown.map { |entry| entry[:label] },
          legend: { position: "bottom" }
        }
      end
    end

    table do
      filter :search, apply: lambda { |relation, value, _context|
        next relation unless value.present?

        relation.where("error_class ILIKE :q", q: AdminScreens::Base.safe_like(value))
      }
      default_sort :error_count, direction: :desc
      column :error_class, title: "Error class"
      column :error_count, title: "Count"
      action :view_api_errors,
        text: "View API errors",
        icon: "exclamation-triangle",
        url: ->(row, context) { "#{context.admin_screen_path("api_errors")}?#{ { search: row.error_class }.to_query }" }
      action :filter_breakdown,
        text: "Filter breakdown",
        icon: "funnel",
        url: ->(row, context) { "#{context.admin_screen_path("most_common_errors")}?#{ { search: row.error_class }.to_query }" }
      paginate per_page: 25
    end

    widget :error_distribution_chart do
      type :chart
      title "Most common errors"
      description "Top API error classes over the last seven days."
      metadata { |context| { period_label: context.period_label(duration: 7.days) || "Last 7 days" } }
      value { |_context| ApiError.where(created_at: 7.days.ago..).count }
      change { |_context| AdminScreens::Base.period_change_label(ApiError.all) }
      chart_type :pie
      series do
        AdminScreens::MostCommonErrors.top_error_breakdown(ApiError.where(created_at: 7.days.ago..)).map do |entry|
          entry[:value]
        end
      end
      chart_options do
        breakdown = AdminScreens::MostCommonErrors.top_error_breakdown(ApiError.where(created_at: 7.days.ago..))
        {
          labels: breakdown.map { |entry| entry[:label] },
          height: 220,
          legend: { position: "bottom" }
        }
      end
      link_to { |context| context.admin_screen_path("most_common_errors") }
    end
  end

  class RootSection < RecordingStudioAdmin::Section
    key "root"
    icon :folder
    title "Admin summary"
    subtitle "Monitor API traffic, users, jobs, and failures"

    recordable "AdminSummarySection",
               find_or_create_by: -> { { key: "root", name: "Admin summary" } },
               parent: -> { AdminRoot.find_or_create_by!(name: "Admin") }

    link :requests, text: "View API requests", url: ->(context) { context.admin_screen_path("api_requests") }, style: :secondary
    link :errors, text: "View API errors", url: ->(context) { context.admin_screen_path("api_errors") }, style: :secondary
    link :most_common_errors,
         text: "View most common errors",
         url: ->(context) { context.admin_screen_path("most_common_errors") },
         style: :secondary
    link :users, text: "View users", url: ->(context) { context.admin_screen_path("users") }, style: :secondary
    link :jobs, text: "View background jobs", url: ->(context) { context.admin_screen_path("background_jobs") }, style: :secondary

          widget "api_requests.widgets.api_activity",
            view_variant: :compact
    widget "api_requests.widgets.api_activity"
          widget "api_errors.widgets.recent_failures",
            view_variant: :compact
    widget "api_errors.widgets.recent_failures"
    widget "most_common_errors.widgets.error_distribution_chart"
          widget "users.widgets.review_completion",
            view_variant: :compact
    widget "users.widgets.active_users"
    widget "users.widgets.most_recent_users"
          widget "background_jobs.widgets.job_throughput",
            view_variant: :compact
    widget "background_jobs.widgets.job_throughput"
  end

  class UsersSection < RecordingStudioAdmin::Section
    key "users"
    icon :user_group
    navigation_parent "root"
    title "Users"
    subtitle "Explore user activity, sign-ins, reviews, and invitations"

    link :overview, text: "View users overview", url: ->(context) { context.admin_screen_path("users") }, style: :secondary
    link :sign_ins, text: "View user sign-ins", url: ->(context) { context.admin_screen_path("user_sign_ins") }, style: :secondary
    link :reviews, text: "View review queue", url: ->(context) { context.admin_screen_path("user_reviews") }, style: :secondary
    link :invitations, text: "View invitations", url: ->(context) { context.admin_screen_path("user_invitations") }, style: :secondary

    widget "users.widgets.active_users",
          view_variant: :compact
    widget "user_sign_ins.widgets.sign_in_activity",
          view_variant: :compact
    widget "user_reviews.widgets.review_volume",
          view_variant: :compact
    widget "users.widgets.review_completion"
    widget "users.widgets.most_recent_users"
    widget "user_invitations.widgets.recent_invites"
  end
end

Rails.application.config.to_prepare do
  RecordingStudioAdmin.register_screen(AdminScreens::ApiRequests)
  RecordingStudioAdmin.register_screen(AdminScreens::ApiErrors)
  RecordingStudioAdmin.register_screen(AdminScreens::Users)
  RecordingStudioAdmin.register_screen(AdminScreens::UserSignIns)
  RecordingStudioAdmin.register_screen(AdminScreens::UserReviews)
  RecordingStudioAdmin.register_screen(AdminScreens::UserInvitations)
  RecordingStudioAdmin.register_screen(AdminScreens::BackgroundJobs)
  RecordingStudioAdmin.register_screen(AdminScreens::MostCommonErrors)
  RecordingStudioAdmin.register_section(AdminScreens::RootSection)
  RecordingStudioAdmin.register_section(AdminScreens::UsersSection)
end
