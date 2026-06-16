# frozen_string_literal: true

module RecordingStudioAdmin
  class SectionsController < ApplicationController
    def index
      @sections = RecordingStudioAdmin.resolve_sections(context: recording_studio_admin_context)
    end

    def show
      @section = RecordingStudioAdmin.resolve_section(key: params[:key], context: recording_studio_admin_context)
    end
  end
end
