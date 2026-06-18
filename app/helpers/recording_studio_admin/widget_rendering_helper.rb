# frozen_string_literal: true

module RecordingStudioAdmin
  module WidgetRenderingHelper
    def recording_studio_widget_presenter(widget, link_policy: nil)
      RecordingStudioAdmin::Widgets::Presenter.new(
        widget,
        link_policy: link_policy || recording_studio_widget_link_policy
      )
    end

    def render_recording_studio_widget(widget, variant: nil, link_policy: nil)
      renderable_widget = variant ? widget.with(view_variant: variant) : widget
      presenter = recording_studio_widget_presenter(renderable_widget, link_policy: link_policy)

      render partial: "recording_studio_admin/shared/widget",
             locals: { widget: renderable_widget, presenter: presenter }
    end

    def render_recording_studio_widget_body(widget)
      render partial: "recording_studio_admin/shared/widgets/#{widget.type}",
             locals: { widget: widget, presenter: recording_studio_widget_presenter(widget) }
    end

    def render_recording_studio_chart_widget(widget)
      render partial: "recording_studio_admin/shared/widgets/chart",
             locals: { widget: widget, presenter: recording_studio_widget_presenter(widget) }
    end

    private

    def recording_studio_widget_link_policy
      if respond_to?(:widget_link_url, true)
        ->(url) { widget_link_url(url) }
      else
        ->(url) { RecordingStudioAdmin::UrlSafety.safe_href(url) }
      end
    end
  end
end