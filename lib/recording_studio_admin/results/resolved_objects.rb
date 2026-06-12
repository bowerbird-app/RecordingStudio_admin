# frozen_string_literal: true

module RecordingStudioAdmin
  module Results
    ResolvedButton = Data.define(:name, :text, :url, :style)
    ResolvedRowAction = Data.define(:name, :text, :url)
    ResolvedFilter = Data.define(:key, :type, :value, :options)
    ResolvedChart = Data.define(:title, :subtitle, :type, :series, :options)
    ResolvedTable = Data.define(:columns, :filters, :rows, :actions, :result)
    ResolvedWidget = Data.define(:key, :type, :title, :subtitle, :value, :change, :link_to, :series, :items, :rows, :metadata)
    ResolvedSection = Data.define(:key, :title, :subtitle, :links, :widgets)
    ResolvedScreen = Data.define(:key, :title, :subtitle, :buttons, :filters, :query_result, :chart, :table, :widgets)
  end
end
