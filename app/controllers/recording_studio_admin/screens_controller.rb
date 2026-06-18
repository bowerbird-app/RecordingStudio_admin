# frozen_string_literal: true

module RecordingStudioAdmin
  class ScreensController < ApplicationController
    def show
      @screen = RecordingStudioAdmin.resolve_screen(key: params[:key], context: recording_studio_admin_context)

      if request.headers["Turbo-Frame"] == "screen-table" || request.xhr?
        render partial: "recording_studio_admin/screens/table_frame", locals: { screen: @screen }
        return
      end

      if request.headers["Turbo-Frame"] == "screen-chart"
        render partial: "recording_studio_admin/screens/chart_frame", locals: { screen: @screen }
        return
      end

      return unless turbo_frame_request?

      render partial: "recording_studio_admin/screens/chart", locals: { screen: @screen }
    end
  end
end
