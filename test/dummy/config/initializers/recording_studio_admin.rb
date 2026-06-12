# frozen_string_literal: true

module AdminScreens
  class Base < RecordingStudioAdmin::Screen
    class << self
      def date_series(relation, field: :created_at)
        relation.group("DATE(#{field})").order("DATE(#{field})").count.map { |date, count| { x: date, y: count } }
      end

      def safe_like(value)
        "%#{ActiveRecord::Base.sanitize_sql_like(value.to_s)}%"
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
      series { |_context| [{ name: "Requests", data: AdminScreens::Base.date_series(ApiRequest.all) }] }
    end

    table do
      filter :search, apply: ->(relation, value, _context) { value.present? ? relation.where("path ILIKE ?", AdminScreens::Base.safe_like(value)) : relation }
      column :created_at
      column :method
      column :status
      column :path
      column :latency_ms, title: "Latency", tooltip: ->(row, _context) { "#{row.latency_ms}ms total request time" }
      paginate per_page: 25
    end

    widget :activity_last_24_hours do
      type :stat
      title "API activity"
      subtitle "Last 24 hours"
      value { |_context| ApiRequest.where(created_at: 24.hours.ago..).count }
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
      series { |_context| [{ name: "Errors", data: AdminScreens::Base.date_series(ApiError.all) }] }
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
      type :stat
      title "Recent failures"
      subtitle "Last 24 hours"
      value { |_context| ApiError.where(created_at: 24.hours.ago..).count }
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
      series { |_context| [{ name: "Activities", data: AdminScreens::Base.date_series(UserActivity.all) }] }
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
      type :stat
      title "Active users"
      subtitle "Last 24 hours"
      value { |_context| UserActivity.where(created_at: 24.hours.ago..).distinct.count(:email) }
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
      series { |_context| [{ name: "Jobs", data: AdminScreens::Base.date_series(BackgroundJobRun.all) }] }
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
      type :stat
      title "Job throughput"
      subtitle "Last 24 hours"
      value { |_context| BackgroundJobRun.where(created_at: 24.hours.ago..).count }
      link_to { |context| context.admin_screen_path("background_jobs") }
    end
  end

  class RootSection < RecordingStudioAdmin::Section
    key "root"
    title "Admin summary"
    subtitle "Monitor API traffic, users, jobs, and failures"

    link :requests, text: "View API requests", url: ->(context) { context.admin_screen_path("api_requests") }, style: :primary
    link :errors, text: "View API errors", url: ->(context) { context.admin_screen_path("api_errors") }, style: :secondary
    link :users, text: "View users", url: ->(context) { context.admin_screen_path("users") }, style: :secondary
    link :jobs, text: "View background jobs", url: ->(context) { context.admin_screen_path("background_jobs") }, style: :secondary

    widget "api_requests.widgets.activity_last_24_hours"
    widget "api_errors.widgets.recent_failures"
    widget "users.widgets.active_users"
    widget "background_jobs.widgets.job_throughput"
  end
end

Rails.application.config.to_prepare do
  RecordingStudioAdmin.register_screen(AdminScreens::ApiRequests)
  RecordingStudioAdmin.register_screen(AdminScreens::ApiErrors)
  RecordingStudioAdmin.register_screen(AdminScreens::Users)
  RecordingStudioAdmin.register_screen(AdminScreens::BackgroundJobs)
  RecordingStudioAdmin.register_section(AdminScreens::RootSection)
end
