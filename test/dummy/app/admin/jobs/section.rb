# frozen_string_literal: true

module AdminScreens
  class JobsSection < RecordingStudioAdmin::Section
    key "jobs"
    icon :bolt
    title "Jobs"
    subtitle "Monitor background job throughput and failures"
    blast_radius :site

    link :background_jobs,
         text: "View background jobs",
         url: ->(context) { context.admin_screen_path("background_jobs") },
         style: :secondary

    widget "widgets.background_jobs.job_throughput",
           view_variant: :compact,
           params: { preset_key: :this_week }
    widget "widgets.background_jobs.job_throughput", params: { preset_key: :this_week }
  end
end
