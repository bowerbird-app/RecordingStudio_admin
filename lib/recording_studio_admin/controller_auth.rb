# frozen_string_literal: true

require "active_support/concern"

module RecordingStudioAdmin
  # Area-aware authenticate / actor helpers shared by the engine controller and
  # generated host Admin::BaseController.
  #
  # Resolves the current admin surface from the request, then reads that
  # surface's +authentication_method+ and +current_actor_method+, falling back
  # to global configuration when the surface leaves them unset.
  #
  # Engine +current_actor+ / +set_recording_studio_admin_current_actor+ match
  # the previous ApplicationController behavior. The generated host template
  # overrides those two methods for host-only nil handling.
  module ControllerAuth
    extend ActiveSupport::Concern

    private

    def authenticate_recording_studio_admin!
      method_name = recording_studio_admin_surface.authentication_method ||
                    RecordingStudioAdmin.configuration.authentication_method
      return send(method_name) if method_name && respond_to?(method_name, true)

      head :unauthorized
    end

    def set_recording_studio_admin_current_actor
      return unless defined?(Current) && Current.respond_to?(:actor=)

      Current.actor = configured_current_actor
    end

    def recording_studio_admin_surface
      @recording_studio_admin_surface ||= RecordingStudioAdmin.configuration.surface_for_request(request)
    end

    def current_actor
      return Current.actor if defined?(Current) && Current.respond_to?(:actor)

      configured_current_actor
    end

    def configured_current_actor
      method_name = recording_studio_admin_surface.current_actor_method ||
                    RecordingStudioAdmin.configuration.current_actor_method
      return send(method_name) if method_name && respond_to?(method_name, true)

      nil
    end
  end
end
