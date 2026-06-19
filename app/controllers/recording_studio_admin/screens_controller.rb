# frozen_string_literal: true

module RecordingStudioAdmin
  class ScreensController < ApplicationController
    def show
      if request.headers["Turbo-Frame"] == "screen-table" || request.xhr?
        render_table
        return
      end

      if request.headers["Turbo-Frame"] == "screen-chart"
        render_chart
        return
      end

      @screen = resolve_screen(
        resolve_summary: false,
        resolve_chart: false,
        resolve_table: true,
        resolve_table_rows: false,
        resolve_table_count: false,
        resolve_widgets: !RecordingStudioAdmin.configuration.async_widgets.enabled
      )
    end

    def chart
      render_chart
    end

    def table
      render_table
    end

    def table_count
      @screen = resolve_screen(
        resolve_summary: false,
        resolve_chart: false,
        resolve_table: true,
        resolve_table_rows: false,
        resolve_table_count: true,
        resolve_widgets: false
      )

      render partial: "recording_studio_admin/screens/table_count", locals: { screen: @screen }
    end

    private

    def render_chart
      @screen = resolve_screen(
        resolve_summary: true,
        resolve_chart: true,
        resolve_table: false,
        resolve_widgets: false
      )

      render partial: "recording_studio_admin/screens/chart_frame", locals: { screen: @screen }
    end

    def render_table
      @screen = resolve_screen(
        resolve_summary: false,
        resolve_chart: false,
        resolve_table: true,
        resolve_table_count: false,
        resolve_widgets: false
      )

      render partial: "recording_studio_admin/screens/table_frame", locals: { screen: @screen }
    end

    def resolve_screen(**options)
      RecordingStudioAdmin.resolve_screen(
        key: params[:key],
        context: recording_studio_admin_context,
        **options
      )
    end
  end
end
