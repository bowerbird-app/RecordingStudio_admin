# frozen_string_literal: true

class AdminApiRequestsExport
  KEY = "admin.api_requests"
  COLUMNS = [
    { key: :created_at, label: "Created at", value: :created_at },
    { key: :method, label: "Method", value: :method },
    { key: :status, label: "Status", value: :status },
    { key: :path, label: "Path", value: :path },
    { key: :latency_ms, label: "Latency", value: :latency_ms }
  ].freeze

  def self.register(config)
    config.register_export(
      KEY,
      label: "API requests",
      description: "Exports API request rows from the admin table.",
      context_types: ["AdminRoot"],
      context_key: "api_requests",
      columns: COLUMNS,
      default_columns: %i[created_at method status path],
      filename: "api-requests.csv",
      required_role: :admin,
      max_rows: 50_000
    ) do |actor:, filters:, controller:, **|
      resolve_rows(actor: actor, filters: filters, controller: controller)
    end
  end

  def self.resolve_rows(actor:, filters:, controller:)
    context = RecordingStudioAdmin::Context.new(
      params: filters.to_h,
      current_actor: actor,
      controller: controller,
      routes: controller,
      view_context: controller.view_context,
      surface: RecordingStudioAdmin.configuration.default_surface
    )

    screen = RecordingStudioAdmin.resolve_screen(
      key: "api_requests",
      context: context,
      resolve_summary: false,
      resolve_chart: false,
      resolve_table: false,
      resolve_widgets: false
    )

    apply_sort(screen.query_result.relation, filters.to_h)
  end

  def self.apply_sort(relation, filters)
    sort = filters["sort"].presence || filters[:sort].presence || "created_at"
    direction = filters["direction"].presence || filters[:direction].presence || "desc"
    direction = "desc" unless %w[asc desc].include?(direction.to_s)
    return relation unless relation.respond_to?(:order) && COLUMNS.any? { |column| column.fetch(:key).to_s == sort.to_s }

    relation.order(sort => direction)
  end
end