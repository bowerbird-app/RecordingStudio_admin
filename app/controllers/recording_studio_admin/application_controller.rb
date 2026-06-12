# frozen_string_literal: true

module RecordingStudioAdmin
  class ApplicationController < ActionController::Base
    layout "application"

    rescue_from RecordingStudioAdmin::DefinitionNotFound, with: :render_not_found

    before_action :authenticate_recording_studio_admin!
    before_action :authorize_recording_studio_admin!
    before_action :set_recording_studio_admin_current_actor

    helper_method :recording_studio_admin_context

    private

    def authenticate_recording_studio_admin!
      method_name = RecordingStudioAdmin.configuration.authentication_method
      return send(method_name) if method_name && respond_to?(method_name, true)

      head :unauthorized
    end

    def authorize_recording_studio_admin!
      return if performed?

      method_name = RecordingStudioAdmin.configuration.authorization_method
      return head :forbidden unless method_name && respond_to?(method_name, true)

      result = send(method_name)
      head :forbidden if result == false && !performed?
    end

    def set_recording_studio_admin_current_actor
      return unless defined?(Current) && Current.respond_to?(:actor=)

      Current.actor = configured_current_actor
    end

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
      return Current.actor if defined?(Current) && Current.respond_to?(:actor)

      configured_current_actor
    end

    def configured_current_actor
      method_name = RecordingStudioAdmin.configuration.current_actor_method
      send(method_name) if method_name && respond_to?(method_name, true)
    end

    def render_not_found
      head :not_found
    end
  end
end
