# frozen_string_literal: true

class Admin::BaseController < ApplicationController
  include RecordingStudioAdmin::AdminActionAuditing
  include RecordingStudioAdmin::ControllerAuth

  layout "admin"

  before_action :authenticate_admin_user!
  before_action :set_recording_studio_admin_current_actor
  before_action :authorize_admin_user!

  helper_method :recording_studio_admin_context, :recording_studio_admin_access_recording, :page_nav_anchor_url,
                :preserve_anchor_url

  private

  def authenticate_admin_user!
    authenticate_recording_studio_admin!
  end

  # Host-only: do not overwrite a Current.actor the host ApplicationController already set.
  def set_recording_studio_admin_current_actor
    return unless defined?(Current) && Current.respond_to?(:actor=)
    return if Current.respond_to?(:actor) && !Current.actor.nil?

    Current.actor = configured_current_actor
  end

  # Host-only: when Current.actor is nil, call the surface/global actor method.
  def current_actor
    return Current.actor if defined?(Current) && Current.respond_to?(:actor) && !Current.actor.nil?

    configured_current_actor
  end

  def authorize_admin_user!
    return if performed?

    RecordingStudioAdmin::Authorization.authorize!(
      recording_studio_admin_context,
      recording: recording_studio_admin_access_recording
    )
  rescue RecordingStudioAdmin::AuthorizationFailed
    head :forbidden
  end

  def recording_studio_admin_context
    @recording_studio_admin_context ||= RecordingStudioAdmin::Context.new(
      params: params.to_unsafe_h,
      current_actor: current_actor,
      controller: self,
      routes: self,
      view_context: view_context,
      surface: recording_studio_admin_surface
    )
  end

  def recording_studio_admin_access_recording
    @recording_studio_admin_access_recording ||= begin
      admin_root = AdminRoot.find_or_create_by!(name: "Admin")
      RecordingStudio.root_recording_for(admin_root)
    end
  end

  def page_nav_anchor_url(default: RecordingStudioAdmin.configuration.default_mount_path)
    safe_url = RecordingStudioAdmin::UrlSafety.safe_href(params[:anchor_url], allow_external: true)
    return default if safe_url.blank? || safe_url == "#"

    safe_url
  end

  def preserve_anchor_url(url)
    safe_url = RecordingStudioAdmin::UrlSafety.safe_href(url)
    anchor_url = page_nav_anchor_url

    return safe_url if safe_url.blank? || anchor_url.blank? || anchor_url == "#"
    return safe_url unless safe_url.start_with?("/")

    uri = URI.parse(safe_url)
    uri.query = Rack::Utils.parse_nested_query(uri.query).reverse_merge("anchor_url" => anchor_url).to_query.presence
    uri.to_s
  rescue URI::InvalidURIError
    safe_url
  end
end
