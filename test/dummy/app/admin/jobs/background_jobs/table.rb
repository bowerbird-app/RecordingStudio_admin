# frozen_string_literal: true

module AdminScreens
  class BackgroundJobs
    table do
      filter :search, apply: RecordingStudioAdmin::Filters::Ilike.on(:job_class)
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
  end
end
