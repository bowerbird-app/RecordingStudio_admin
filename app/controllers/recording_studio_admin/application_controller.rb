# frozen_string_literal: true

require_relative "../../helpers/recording_studio_admin/widget_rendering_helper"
require_relative "../../helpers/recording_studio_admin/geo_chart_helper"

module RecordingStudioAdmin
  class ApplicationController < ActionController::Base
    if defined?(RecordingStudio::RootSwitchable::ControllerSupport)
      include RecordingStudio::RootSwitchable::ControllerSupport
    end
    include RecordingStudioAdmin::AdminActionAuditing

    layout :recording_studio_admin_layout

    helper RecordingStudioAdmin::WidgetRenderingHelper
    helper RecordingStudioAdmin::GeoChartHelper
    helper ::RecordingStudioExportable::ExportsHelper if defined?(::RecordingStudioExportable::ExportsHelper)

    rescue_from RecordingStudioAdmin::DefinitionNotFound, with: :render_not_found
    rescue_from RecordingStudioAdmin::AuthorizationFailed, with: :render_forbidden

    before_action :authenticate_recording_studio_admin!
    before_action :set_recording_studio_admin_current_actor

    helper_method :recording_studio_admin_context, :recording_studio_admin_surface, :page_nav_anchor_url,
                  :preserve_anchor_url, :widget_link_url, :recording_studio_admin_screen_region_path,
                  :recording_studio_admin_exportable_available?, :recording_studio_admin_export_authorized?

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

    def recording_studio_admin_surface
      @recording_studio_admin_surface ||= RecordingStudioAdmin.configuration.surface_for_request(request)
    end

    def page_nav_anchor_url(default: nil)
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

    def widget_link_url(url)
      safe_url = preserve_anchor_url(url)
      return if widget_link_points_to_current_page?(safe_url)

      safe_url
    end

    def recording_studio_admin_screen_region_path(key, region, query: request.query_parameters)
      base_path = recording_studio_admin_context.admin_screen_path(key)
      path = case region.to_sym
             when :chart then "#{base_path}/chart"
             when :table then "#{base_path}/table"
             when :table_count then "#{base_path}/table_count"
             else base_path
             end
      query_hash = query.respond_to?(:to_unsafe_h) ? query.to_unsafe_h : query.to_h
      query_string = query_hash.compact.to_query
      return path if query_string.blank?

      "#{path}?#{query_string}"
    end

    def recording_studio_admin_exportable_available?
      defined?(::RecordingStudioExportable) && defined?(::RecordingStudioExportable::ExportsHelper)
    end

    def recording_studio_admin_export_authorized?(export_key, screen_key)
      return false unless recording_studio_admin_exportable_available?
      return false if export_key.blank? || screen_key.blank?

      context_recording = recording_studio_admin_context.access_recording
      actor = recording_studio_admin_context.current_actor
      return false unless context_recording && actor

      normalized_key = ::RecordingStudioExportable.configuration.normalize_key(export_key)
      allowed_keys = ::RecordingStudioExportable.configuration.export_keys_for(
        recording: context_recording,
        actor: actor,
        context: screen_key
      )
      allowed_keys.include?(normalized_key)
    rescue StandardError
      false
    end

    def widget_link_points_to_current_page?(url)
      return false if url.blank? || url == "#" || !url.start_with?("/")

      target_path, target_query = normalized_relative_url_parts(url)

      target_path == request.path && target_query == normalized_query_hash(request.query_string)
    rescue URI::InvalidURIError
      false
    end

    def normalized_relative_url_parts(url)
      uri = URI.parse(url)
      [uri.path, normalized_query_hash(uri.query)]
    end

    def normalized_query_hash(query_string)
      Rack::Utils.parse_nested_query(query_string).except("anchor_url")
    end

    def current_actor
      return Current.actor if defined?(Current) && Current.respond_to?(:actor)

      configured_current_actor
    end

    def configured_current_actor
      method_name = recording_studio_admin_surface.current_actor_method ||
                    RecordingStudioAdmin.configuration.current_actor_method
      send(method_name) if method_name && respond_to?(method_name, true)
    end

    def recording_studio_admin_layout
      recording_studio_admin_surface.engine_layout || RecordingStudioAdmin.configuration.engine_layout
    end

    def render_not_found
      head :not_found
    end

    def render_forbidden
      head :forbidden
    end
  end
end
