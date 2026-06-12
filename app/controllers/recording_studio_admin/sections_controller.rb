# frozen_string_literal: true

module RecordingStudioAdmin
  class SectionsController < ApplicationController
    def show
      @section = RecordingStudioAdmin.resolve_section(key: params[:key], context: recording_studio_admin_context)
    end
  end
end
