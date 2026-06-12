# frozen_string_literal: true

module RecordingStudioAdmin
  class ApplicationController < ActionController::Base
    layout "application"

    rescue_from RecordingStudioAdmin::DefinitionNotFound, with: :render_not_found

    helper_method :recording_studio_admin_context

    private

    def recording_studio_admin_context
      @recording_studio_admin_context ||= RecordingStudioAdmin::Context.new(
        params: params.to_unsafe_h,
        current_actor: current_actor,
        controller: self,
        routes: self,
        view_context: view_context
      )
    end

    def current_actor
      Current.actor if defined?(Current)
    end

    def render_not_found
      head :not_found
    end
  end
end
