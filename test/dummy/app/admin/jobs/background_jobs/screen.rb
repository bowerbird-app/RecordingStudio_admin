# frozen_string_literal: true

module AdminScreens
  class BackgroundJobs < Base
    key "background_jobs"
    icon :bolt
    title "Background jobs"
    subtitle "Monitor queue throughput and job failures"
    query { |_context| BackgroundJobRun.all }
    filter :date_range, field: :created_at, default: :last_30_days
    filter :queue, options: -> { BackgroundJobRun.distinct.order(:queue).pluck(:queue) }
  end
end