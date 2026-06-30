# frozen_string_literal: true

module RecordingStudioAdmin
  class ScreenWidgetsController < ApplicationController
    def show
      widget = RecordingStudioAdmin::Resolvers::ScreenResolver.resolve_widget(
        key: params[:screen_key],
        widget_key: params[:widget_key],
        view_variant: params[:widget_view_variant],
        context: recording_studio_admin_context
      )

      render partial: "recording_studio_admin/shared/widget_frame",
             locals: { parent: :screen, parent_key: params[:screen_key], widget: widget }
    end
  end
end
