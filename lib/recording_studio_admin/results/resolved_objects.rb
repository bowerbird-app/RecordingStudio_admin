# frozen_string_literal: true

module RecordingStudioAdmin
  module Results
    ResolvedButton = Data.define(:name, :text, :url, :style)
    ResolvedRowAction = Data.define(:name, :text, :url)
    ResolvedFilter = Data.define(:key, :type, :value, :options, :param_key, :start_param, :end_param)
    ResolvedChart = Data.define(:title, :subtitle, :type, :series, :options)
    ResolvedTable = Data.define(:columns, :filters, :rows, :actions, :result)
    ResolvedMetric = Data.define(:key, :label, :value, :change, :change_good_when, :description, :period_label)
    ResolvedWidget = Data.define(
      :key,
      :type,
      :title,
      :subtitle,
      :description,
      :value,
      :change,
      :change_good_when,
      :link_to,
      :series,
      :chart_type,
      :chart_options,
      :list_options,
      :items,
      :rows,
      :metadata,
      :view_variant
    )
    ResolvedSectionRecording = Data.define(:recordable, :recording, :root_recording, :parent_recording)
    ResolvedSection = Data.define(:key, :title, :subtitle, :links, :widgets, :recordable, :recording)
    ResolvedScreen = Data.define(
      :key,
      :title,
      :subtitle,
      :buttons,
      :filters,
      :query_result,
      :chart,
      :table,
      :metrics,
      :widgets
    )
  end
end
