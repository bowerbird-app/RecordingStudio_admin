# frozen_string_literal: true

module RecordingStudioAdmin
  class ScreensController < ApplicationController
    def show
      @screen = RecordingStudioAdmin.resolve_screen(key: params[:key], context: recording_studio_admin_context)

      return unless turbo_frame_request? || request.xhr?

      render partial: "recording_studio_admin/screens/chart", locals: { screen: @screen }
    end
  end
end
