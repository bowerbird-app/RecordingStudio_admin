# frozen_string_literal: true

RecordingStudioAdmin::Engine.routes.draw do
  root "sections#show", defaults: { key: "root" }

  get "sections/:key", to: "sections#show", as: :section
  get "screens/:key", to: "screens#show", as: :screen
end
