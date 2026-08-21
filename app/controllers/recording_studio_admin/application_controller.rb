# frozen_string_literal: true

require_relative "../../helpers/recording_studio_admin/widget_rendering_helper"
require_relative "../../helpers/recording_studio_admin/geo_chart_helper"

module RecordingStudioAdmin
  # rubocop:disable Metrics/ClassLength
  class ApplicationController < ActionController::Base
    if defined?(RecordingStudio::RootSwitchable::ControllerSupport)
      include RecordingStudio::RootSwitchable::ControllerSupport
    end
    include RecordingStudioAdmin::AdminActionAuditing

    # Only meaningful to a widget frame request, so they are dropped when redirecting to a page.
    FRAME_ONLY_QUERY_PARAMS = %w[widget_view_variant widget_usage_index widget_render_variant].freeze

    layout :recording_studio_admin_layout

    helper RecordingStudioAdmin::WidgetRenderingHelper
    helper RecordingStudioAdmin::GeoChartHelper
    helper ::RecordingStudio::LayoutHelper if defined?(::RecordingStudio::LayoutHelper)
    helper ::RecordingStudioExportable::ExportsHelper if defined?(::RecordingStudioExportable::ExportsHelper)

    rescue_from RecordingStudioAdmin::DefinitionNotFound, with: :render_not_found
    rescue_from RecordingStudioAdmin::AuthorizationFailed, with: :render_forbidden

    before_action :authenticate_recording_studio_admin!
    before_action :set_recording_studio_admin_current_actor

    helper_method :recording_studio_admin_context, :recording_studio_admin_surface, :page_nav_anchor_url,
                  :preserve_anchor_url, :widget_link_url, :recording_studio_admin_screen_region_path,
                  :recording_studio_admin_exportable_available?, :recording_studio_admin_export_authorized?,
                  :recording_studio_admin_export_token, :recording_studio_admin_token_export_available?,
                  :recording_studio_admin_exportable_exports_path, :recording_studio_admin_default_layout?

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

    # rubocop:disable Metrics/MethodLength
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
    # rubocop:enable Metrics/MethodLength

    # Region and widget endpoints answer Turbo Frame fetches with a bare partial. A browser that
    # lands on one as a page (direct visit, bookmark, or JS-less link) would render that partial
    # without the admin layout, so those visits are sent to the page that owns the frame.
    def recording_studio_admin_page_visit?
      request.headers["Turbo-Frame"].blank? && !request.xhr?
    end

    def redirect_to_recording_studio_admin_page(path)
      query = request.query_parameters.except(*FRAME_ONLY_QUERY_PARAMS).to_query

      redirect_to(query.present? ? "#{path}?#{query}" : path)
    end

    def recording_studio_admin_exportable_available?
      defined?(::RecordingStudioExportable::ExportsHelper)
    end

    # rubocop:disable Metrics/MethodLength
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
    # rubocop:enable Metrics/MethodLength

    def recording_studio_admin_token_export_available?(screen_key)
      return false unless recording_studio_admin_exportable_available?
      return false if screen_key.blank?

      screen = RecordingStudioAdmin.registry.screen_for(screen_key)
      return false unless screen

      export_config = screen.export_config || screen_export_config_from_surface
      export_config.present?
    rescue StandardError
      false
    end

    # rubocop:disable Metrics/MethodLength, Metrics/PerceivedComplexity, Metrics/AbcSize, Metrics/CyclomaticComplexity
    def recording_studio_admin_export_token(screen_key:, columns:, filters:)
      return nil unless recording_studio_admin_token_export_available?(screen_key)

      screen = RecordingStudioAdmin.registry.screen_for(screen_key)
      return nil unless screen

      export_config = screen.export_config || screen_export_config_from_surface
      return nil unless export_config

      context = recording_studio_admin_context
      return nil unless context&.access_recording && context.current_actor

      required_role = export_config[:required_role] || :view
      return nil unless authorized_for_export_token?(context, required_role)

      ensure_recording_studio_admin_trusted_export_source!

      export_context = context
      relation = export_context.query_result&.relation
      export_params = export_context.params.to_h.deep_stringify_keys.merge(
        (filters || {}).to_h.deep_stringify_keys
      ).except("page", "columns", "columns_present", "anchor_url")
      trusted_columns = trusted_export_columns_for(screen, columns, export_context)
      token = ::RecordingStudioExportable.issue_trusted_token(
        context_recording: context.access_recording,
        actor: context.current_actor,
        source: "recording_studio_admin",
        screen_identifier: screen_key,
        columns: trusted_columns,
        row_resolver: -> { relation || resolve_export_relation(screen_key, export_params, export_context) },
        ttl: 5.minutes
      )
      token.id if token.respond_to?(:id)
    rescue NameError, ::RecordingStudioExportable::Error
      nil
    end
    # rubocop:enable Metrics/MethodLength, Metrics/PerceivedComplexity, Metrics/AbcSize, Metrics/CyclomaticComplexity

    def recording_studio_admin_exportable_exports_path
      return recording_studio_exportable.exports_path if respond_to?(:recording_studio_exportable)

      ::RecordingStudioExportable::Engine.routes.url_helpers.exports_path
    rescue NameError
      nil
    end

    def screen_export_config_from_surface
      surface = recording_studio_admin_surface
      return unless surface&.allow_export_default_role

      { required_role: surface.allow_export_default_role.to_sym }
    end

    def authorized_for_export_token?(context, required_role)
      ::RecordingStudioAccessible.authorized?(
        actor: context.current_actor,
        recording: context.access_recording,
        role: required_role
      )
    rescue StandardError
      false
    end

    def ensure_recording_studio_admin_trusted_export_source!
      configuration = ::RecordingStudioExportable.configuration
      sources = Array(configuration.trusted_export_sources).map(&:to_s)
      configuration.trusted_export_sources = sources | ["recording_studio_admin"]
    end

    def trusted_export_columns_for(screen, column_keys, export_context)
      columns_by_key = screen.table_value.columns.index_by { |column| column.key.to_s }
      Array(column_keys).map(&:to_s).filter_map do |key|
        column = columns_by_key[key]
        next unless column

        {
          key: column.key,
          label: column.title,
          value: ->(row) { column.cell(row, export_context) }
        }
      end
    end

    # rubocop:disable Metrics/MethodLength
    def resolve_export_relation(screen_key, export_params, export_context)
      context = RecordingStudioAdmin::Context.new(
        params: export_params,
        current_actor: export_context.current_actor,
        controller: export_context.controller,
        routes: export_context.routes,
        surface: export_context.surface
      )
      RecordingStudioAdmin.resolve_screen(
        key: screen_key,
        context: context,
        resolve_widgets: false,
        resolve_summary: false,
        resolve_chart: false,
        resolve_table: false
      )
      context.query_result&.relation
    end
    # rubocop:enable Metrics/MethodLength

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
      return send(method_name) if method_name && respond_to?(method_name, true)

      nil
    end

    def recording_studio_admin_layout
      recording_studio_admin_surface.engine_layout ||
        RecordingStudioAdmin.configuration.engine_layout ||
        RecordingStudioAdmin::Configuration::DEFAULT_ENGINE_LAYOUT
    end

    def recording_studio_admin_default_layout?
      recording_studio_admin_layout == RecordingStudioAdmin::Configuration::DEFAULT_ENGINE_LAYOUT
    end

    def render_not_found
      head :not_found
    end

    def render_forbidden
      head :forbidden
    end
    # rubocop:enable Metrics/ClassLength
  end
end
