# frozen_string_literal: true

module RecordingStudioAdmin
  module Results
    ResolvedButton = Data.define(:name, :text, :url, :style)
    ResolvedRowAction = Data.define(:name, :text, :url, :icon, :method, :confirm, :destructive)
    ResolvedFilter = Data.define(:key, :type, :value, :options, :param_key, :start_param, :end_param, :preset_param)
    ResolvedChart = Data.define(:title, :subtitle, :type, :series, :options)
    ResolvedTable = Data.define(:columns, :filters, :rows, :actions, :result, :available_columns, :selected_column_keys)
    ResolvedSummary = Data.define(:label, :value, :change, :change_good_when, :period_label, :show_metric,
                                  :show_change, :show_period)
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
      :link_label,
      :series,
      :chart_type,
      :chart_options,
      :list_options,
      :items,
      :rows,
      :metadata,
      :view_variant,
      :show_metric,
      :show_change,
      :show_period
    )
    ResolvedAvailableWidget = Data.define(
      :key,
      :title,
      :description,
      :type,
      :chart_type,
      :screen_key,
      :section_key,
      :source,
      :recording,
      :recordable,
      :view_variant,
      :params,
      :surface_key
    )
    ResolvedSectionRecording = Data.define(:recordable, :recording, :root_recording, :parent_recording)
    ResolvedAvailableAdminItem = Data.define(
      :type,
      :key,
      :title,
      :subtitle,
      :icon,
      :url,
      :parent_key,
      :availability_scope,
      :search_text
    )
    ResolvedSectionListItem = Data.define(:key, :title, :subtitle, :icon, :url)
    ResolvedAvailableSection = Data.define(:key, :title, :subtitle, :icon, :url, :availability_scope)
    ResolvedSection = Data.define(:key, :title, :subtitle, :icon, :links, :widgets, :recordable, :recording)
    ResolvedScreen = Data.define(
      :key,
      :title,
      :subtitle,
      :buttons,
      :filters,
      :query_result,
      :summary,
      :chart,
      :table,
      :widgets
    )
  end
end
