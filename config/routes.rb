# frozen_string_literal: true

RecordingStudioAdmin::Engine.routes.draw do
  root "sections#show"

  get "sections", to: "sections#index", as: :sections
  get "sections/:key", to: "sections#show", as: :section
  get "screens/:key", to: "screens#show", as: :screen
end
