# frozen_string_literal: true

RecordingStudioAdmin::Engine.routes.draw do
  root "sections#show"

  get "sections", to: "sections#index", as: :sections
  get "sections/:key", to: "sections#show", as: :section
  get "sections/:section_key/widgets/:widget_key", to: "section_widgets#show", as: :section_widget,
                                                   constraints: { widget_key: %r{[^/]+(?:\.[^/]+)*} }, format: false
  get "screens/:key", to: "screens#show", as: :screen
  get "screens/:key/chart", to: "screens#chart", as: :screen_chart
  get "screens/:key/table", to: "screens#table", as: :screen_table
  get "screens/:key/table_count", to: "screens#table_count", as: :screen_table_count
  get "screens/:screen_key/widgets/:widget_key", to: "screen_widgets#show", as: :screen_widget,
                                                 constraints: { widget_key: %r{[^/]+(?:\.[^/]+)*} }, format: false
end
