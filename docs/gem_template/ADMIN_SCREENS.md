# RecordingStudioAdmin screens, sections, and widgets

This guide explains the practical host-app workflow for building admin UI with `RecordingStudioAdmin`.

## Mental model

There are three main definition types:

- `RecordingStudioAdmin::Screen`: a detailed analytics page with a query, filters, chart, table, summary, and optional screen-owned widgets
- `RecordingStudioAdmin::Section`: an overview page with links plus widgets pulled from screens or standalone widget definitions
- `RecordingStudioAdmin::Widget`: a reusable card rendered inside a screen or section

Think of a section as the landing page for an admin area, and a screen as the deeper analytical view behind that landing page.

## Setup flow

A complete host-app integration usually looks like this:

1. Mount the engine and configure access recording resolution
2. Define one or more screen classes
3. Define one or more section classes
4. Register those classes from `Rails.application.config.to_prepare`
5. Link between pages with `context.admin_screen_path` and `context.admin_section_path`

When the host app uses the optional `recording_studio_admin:admin_root` generator, it can also build the landing page and
search UI from `recording_studio_admin_context.available_admin_sections` and
`recording_studio_admin_context.available_admin_items`.

## Minimal screen example

```ruby
module AdminScreens
  class ApiRequests < RecordingStudioAdmin::Screen
    key "api_requests"
    icon :document_text
    title "API requests"
    subtitle "Monitor API traffic and failures"

    query { |_context| ApiRequest.all }

    filter :date_range, field: :created_at, default: :last_30_days
    filter :group_by, values: %i[hour day week month year], default: :day
    filter :status, options: -> { ApiRequest.distinct.order(:status).pluck(:status) }

    summary do
      label "Total requests"
      change_good_when :up
    end

    chart do
      title "Requests over time"
      type :line
      series do |context|
        relation = context.query_result.relation
        bucket = context.filter_value(:group_by) || :day

        [
          {
            name: "Requests",
            data: relation.group(Arel.sql("DATE_TRUNC('#{bucket}', created_at)"))
                          .order(Arel.sql("DATE_TRUNC('#{bucket}', created_at)"))
                          .count
                          .map { |date, count| { x: date, y: count } }
          }
        ]
      end
    end

    table do
      filter :search, apply: ->(relation, value, _context) {
        value.present? ? relation.where("path ILIKE ?", "%#{ActiveRecord::Base.sanitize_sql_like(value)}%") : relation
      }

      column :created_at
      column :method
      column :status
      column :path

      action :view_errors,
             text: "View errors",
             url: ->(row, context) { "#{context.admin_screen_path('api_errors')}?#{ { search: row.path }.to_query }" }

      paginate per_page: 25, mode: :infinite
    end

    widget :api_activity do
      type :chart
      title "API activity"
      value { |context| context.query_result.count }
      chart_type :area
      series do |context|
        [
          {
            name: "Requests",
            data: context.query_result.relation.group(:created_at).count.map { |x, y| { x: x, y: y } }
          }
        ]
      end
      link_to { |context| context.admin_screen_path("api_requests") }
    end
  end
end
```

## Minimal section example

```ruby
module AdminScreens
  class RootSection < RecordingStudioAdmin::Section
    key "root"
    icon :folder
    title "Admin section"
    subtitle "Monitor API traffic, users, jobs, and failures"

    link :requests,
         text: "View API requests",
         url: ->(context) { context.admin_screen_path("api_requests") },
         style: :secondary

    widget "api_requests.widgets.api_activity", view_variant: :compact
  end
end
```

## Registering definitions

Register every screen and section from `Rails.application.config.to_prepare`:

```ruby
Rails.application.config.to_prepare do
  RecordingStudioAdmin.register_screen(AdminScreens::ApiRequests)
  RecordingStudioAdmin.register_screen(AdminScreens::ApiErrors)
  RecordingStudioAdmin.register_section(AdminScreens::RootSection)
end
```

That pattern matters because Rails reloads app classes in development. `to_prepare` ensures the registry points at the current class objects.

## Lookup and resolver methods

The top-level module exposes the runtime methods most apps and tests need:

```ruby
RecordingStudioAdmin.register_screen(AdminScreens::ApiRequests)
RecordingStudioAdmin.register_section(AdminScreens::RootSection)

RecordingStudioAdmin.screen_for("api_requests")
RecordingStudioAdmin.section_for("root")
RecordingStudioAdmin.widget_for("api_requests.widgets.api_activity")

RecordingStudioAdmin.resolve_sections(context: context)
RecordingStudioAdmin.resolve_section(key: "root", context: context)
RecordingStudioAdmin.resolve_screen(key: "api_requests", context: context)
RecordingStudioAdmin.resolve_widget(key: "api_requests.widgets.api_activity", context: context)
```

The mounted engine routes line up with those APIs:

```text
/admin
/admin/sections
/admin/sections/:key
/admin/screens/:key
```

`/admin` resolves the `root` section by default, so most host apps register a `root` section even when they also generate a separate `/admin/root` host-app page.

## When to use a section vs a screen

Use a section when you need:

- an overview page
- cross-screen navigation links
- a dashboard made of widgets
- optional section-backed RecordingStudio recordables

Use a screen when you need:

- a primary query relation
- chart and table filters
- a sortable or paginated table
- row actions
- widgets that derive from the same analytical surface

## Widget key rules

Screen-owned widgets are automatically namespaced:

```text
api_requests.widgets.api_activity
users.widgets.review_completion
```

When a section wants to reuse a screen widget, it must reference the full key:

```ruby
widget "api_requests.widgets.api_activity"
```

## Section widget customization

Sections can customize how a widget is displayed without changing the widget definition itself:

```ruby
widget "api_requests.widgets.api_activity",
       view_variant: :compact,
       title: "Request volume",
       chart_type: :bar,
       chart_options: { height: 180 },
       params: { duration: 7.days, group_by: :day }
```

Supported section widget view variants are:

- `:card`
- `:compact`

`params` become widget params on the derived context, which is how sections can request a different duration or grouping than the screen default.

Those params pair with context helpers that preserve widget period semantics:

```ruby
context.widget_period_label(default_preset_key: :this_week)
context.widget_time_range(default_preset_key: :this_week)
context.widget_filter_params(default_preset_key: :this_week, preset_param: :date_range_preset)
```

## RecordingStudio-backed sections

Register sections globally, then enable them on the recordable types that should expose them:

```ruby
class AdminRoot < ApplicationRecord
  include RecordingStudioAdmin::AllowsAdminSections

  recording_studio_admin_sections do
    section :root
    section :users
  end
end
```

That enablement is separate from the optional section-backed recordable below.

If section enablement should come from another source, configure `admin_sections_resolver`. Otherwise prefer the
`RecordingStudioAdmin::AllowsAdminSections` DSL because it keeps section visibility close to the recordable type.

Sections can declare an app-owned recordable:

```ruby
recordable "AdminSection",
           find_or_create_by: -> { { key: "root", name: "Admin section" } },
           parent: -> { AdminRoot.find_or_create_by!(name: "Admin") }
```

Use this when the section needs its own RecordingStudio object. This is separate from the access recording used for authorization.

## Access and authorization

Every request still requires the current access recording configured in `RecordingStudioAdmin.configure`.

The distinction is important:

- access recording: determines whether the actor may use the mounted admin UI at all
- enabled admin sections: determine which registered sections appear for the current recording's recordable type
- section recordable: creates or resolves the RecordingStudio object owned by that section

The availability APIs expose that distinction in code:

```ruby
RecordingStudioAdmin.available_sections(context: context, recording: recording, placement: :root)
RecordingStudioAdmin.available_admin_items(
  context: context,
  recording: recording,
  placement: :all,
  parent: nil,
  include: %i[sections screens]
)
RecordingStudioAdmin.enabled_admin_section_keys(recording: recording, context: context)
```

`placement` accepts `:all`, `:root`, or `:descendant`. `parent` filters search results down to descendants of a specific available item key.

## Path helpers inside definitions

Prefer the context helpers instead of hard-coded strings:

```ruby
context.admin_screen_path("api_requests")
context.admin_section_path("users")
context.admin_sections_path
```

These helpers honor mounted routes when available and fall back to the configured `default_mount_path`.

Mounted controllers and views also expose navigation helpers for host-app back links and safe widget links:

```ruby
preserve_anchor_url(section.url)
page_nav_anchor_url(default: "/")
widget_link_url(widget.link_to)
```

## Resolver APIs

The engine exposes resolver methods that return structured result objects:

```ruby
RecordingStudioAdmin.resolve_screen(key: "api_requests", context: context)
RecordingStudioAdmin.resolve_section(key: "root", context: context)
RecordingStudioAdmin.resolve_widget(key: "api_requests.widgets.api_activity", context: context)
RecordingStudioAdmin.resolve_sections(context: context)
```

That is the API to use in tests, future non-HTML integrations, or internal debugging.

## Suggested host-app layout

```text
app/
  admin_screens/
    api_requests.rb
    api_errors.rb
    root_section.rb
config/
  initializers/
    recording_studio_admin.rb
```

Keep definitions in app-owned classes. Keep configuration and registration in the initializer.

## Common mistakes

| Mistake | Why it causes problems |
|---------|------------------------|
| Registering screens at file load time | development reloads can leave stale definitions in the registry |
| Hard-coding `/admin/screens/...` links | custom mount paths and route helper fallbacks drift |
| Putting query logic in controllers | the engine expects screen definitions and resolvers to own that behavior |
| Confusing the section recordable with the access recording | authorization and section ownership are separate concerns |
| Reaching into views to format or compute data | formatting belongs in views, but query structure belongs in definitions or app services |

## Best reference in this repository

The dummy app initializer is the best real example to copy from:

- `test/dummy/config/initializers/recording_studio_admin.rb`

It includes:

- multiple screen types
- reused widgets
- section links
- section recordables
- `to_prepare` registration
