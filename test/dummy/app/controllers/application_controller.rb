class ApplicationController < ActionController::Base
  include RecordingStudio::RootSwitchable::ControllerSupport

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  layout :application_layout

  before_action :authenticate_user!
  before_action :set_current_actor
  before_action :authorize_dummy_page_access!, unless: :devise_controller?

  private

  def application_layout
    devise_controller? ? "application" : "flat_pack_sidebar"
  end

  def set_current_actor
    Current.actor = current_user
  end

  def authorize_dummy_page_access!
    return if accessible_for_current_root?

    head :forbidden
  end

  def accessible_for_current_root?
    root_recording = current_root_recording
    return false unless root_recording

    RecordingStudioAccessible.authorized?(actor: current_user, recording: root_recording, role: :view)
  end
end
