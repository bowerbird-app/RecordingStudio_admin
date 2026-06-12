# frozen_string_literal: true

module RecordingStudioAdmin
  class ScreensController < ApplicationController
    def show
      @screen = RecordingStudioAdmin.resolve_screen(key: params[:key], context: recording_studio_admin_context)
    end
  end
end
