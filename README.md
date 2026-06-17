# RecordingStudioAdmin

`RecordingStudioAdmin` is the canonical Rails engine for reusable Recording Studio admin and reporting screens.

It provides two separate capabilities:

- **Admin root scaffolding**: optional, generated host-app files for an editable sitewide admin root recordable.
- **Reusable admin screen engine**: code-defined sections, screens, widgets, filters, charts, tables, and resolvers that can be mounted anywhere.

The old admin gem is not an implementation guide for this replacement.

## Quick start

1. Add the gem to the host app and run the install generator:

```bash
bin/rails generate recording_studio_admin:install
```

2. Mount the engine, usually at `/admin`:

```ruby
mount RecordingStudioAccessible::Engine, at: "/admin/access"
mount RecordingStudioAdmin::Engine, at: "/admin"
```

3. Configure authentication, actor lookup, and the current access recording:

```ruby
RecordingStudioAdmin.configure do |config|
  config.default_mount_path = "/admin"
  config.authentication_method = :authenticate_user!
  config.current_actor_method = :current_user
  config.access_recording_resolver = ->(context) { context.controller.current_root_recording }
end
```

4. Define screens and sections in app-owned classes, then register them from a `to_prepare` block so development reloads stay correct:

```ruby
module AdminScreens
  class ApiRequests < RecordingStudioAdmin::Screen
    key "api_requests"
    title "API requests"
    query { |_context| ApiRequest.all }
    filter :date_range, field: :created_at, default: :last_30_days

    chart do
      title "Requests over time"
      type :line
      series do |context|
        [
          {
            name: "Requests",
            data: context.query_result.relation.group(:created_at).count.map { |x, y| { x: x, y: y } }
          }
        ]
      end
    end

    table do
      column :created_at
      column :path
      column :status
    end

    widget :api_activity do
      type :number
      title "API activity"
      value { |context| context.query_result.count }
      link_to { |context| context.admin_screen_path("api_requests") }
    end
  end

  class RootSection < RecordingStudioAdmin::Section
    key "root"
    title "Admin summary"
    link :requests, text: "View API requests", url: ->(context) { context.admin_screen_path("api_requests") }
    widget "api_requests.widgets.api_activity", view_variant: :compact
  end
end

Rails.application.config.to_prepare do
  RecordingStudioAdmin.register_screen(AdminScreens::ApiRequests)
  RecordingStudioAdmin.register_section(AdminScreens::RootSection)
end
```

5. Link to screens and sections with the context helpers:

```ruby
context.admin_screen_path("api_requests")
context.admin_section_path("root")
context.admin_sections_path
```

The generated host-app admin root page can also list and search the currently available admin destinations:

```ruby
sections = recording_studio_admin_context.available_admin_sections(
  recording: recording_studio_admin_access_recording
)

items = recording_studio_admin_context.available_admin_items(
  recording: recording_studio_admin_access_recording,
  include: %i[sections screens]
)
```

## Requirements

- Rails 8.1+
- RecordingStudio
- RecordingStudioAccessible
- FlatPack

`RecordingStudioAccessible` is required. The generated admin root includes `RecordingStudioAccessible::AllowsAccessibleChildren` by default.

Recordable types opt into admin sections with `RecordingStudioAdmin::AllowsAdminSections`:

```ruby
class AdminRoot < ApplicationRecord
  include RecordingStudio::Recordable
  include RecordingStudioAccessible::AllowsAccessibleChildren
  include RecordingStudioAdmin::AllowsAdminSections

  recording_studio_recordable label: "Admin", root: true
  recording_studio_accessible_children :access

  recording_studio_admin_sections do
    section :root
    section :users
  end
end
```

Registering a section defines the reusable admin capability. Enabling it on a recordable type decides where it appears.

The engine protects mounted screens through a configurable host-app authentication hook plus a mandatory context-owned `RecordingStudio::Recording` access target. By default it calls `authenticate_user!`, reads the actor from `current_user`, and checks `RecordingStudioAccessible.authorized?` with role `:view` before resolving sections, widgets, or screen queries:

```ruby
RecordingStudioAdmin.configure do |config|
  config.authentication_method = :authenticate_user!
  config.current_actor_method = :current_user
  config.access_recording_resolver = lambda do |context|
    context.controller.current_root_recording
  end
end
```

If the configured authentication method is unavailable, the engine returns `401 Unauthorized` instead of rendering admin data.
If the access recording is unavailable or `RecordingStudioAccessible` denies access for the current actor, the engine returns `403 Forbidden`.

## Routing

Mount the screen engine wherever you need admin or reporting screens:

```ruby
mount RecordingStudioAdmin::Engine, at: "/admin"
```

The engine exposes explicit routes only:

```text
/admin
/admin/sections
/admin/sections/:key
/admin/screens/:key
```

`/admin` resolves the `root` section by default. If no `root` section is registered, that request returns `404 Not Found`.

There are no catch-all routes.

## How admin screens are assembled

The engine is driven by three definition types:

- `RecordingStudioAdmin::Screen`: a detailed page with a query, main filters, chart, table, summary, and screen-owned widgets.
- `RecordingStudioAdmin::Section`: a summary page with links plus a collection of widgets pulled from screens or standalone widget definitions.
- `RecordingStudioAdmin::Widget`: a reusable card definition rendered either inside screens or sections.

The runtime flow is:

1. The controller builds a `RecordingStudioAdmin::Context` from request params, the current actor, route helpers, and view context.
2. The engine authenticates the request and resolves the current access recording.
3. A resolver (`resolve_screen`, `resolve_section`, `resolve_widget`, or `resolve_sections`) turns the code definition into structured result objects.
4. FlatPack-based views render those result objects.

This means host apps own the query logic and admin information architecture in Ruby, while the engine owns routing, authorization checks, resolver orchestration, and rendering.

## Access, enablement, and section ownership

The refactored engine keeps three separate concerns apart:

- access recording: which `RecordingStudio::Recording` gates use of the mounted admin UI
- enabled admin sections: which registered sections should appear for the current recording's recordable type
- section recordable: the optional RecordingStudio-backed object created or resolved after a section page is opened

Those concerns often point at related data, but they are not interchangeable.

## Definitions and resolvers

Sections, screens, widgets, filters, charts, and tables are code-defined. Controllers and views consume structured resolver results; they do not own query or rendering logic.

```ruby
RecordingStudioAdmin.register_screen(ApiRequestsScreen)
RecordingStudioAdmin.register_section(AdminRootSection)

RecordingStudioAdmin.resolve_screen(key: "api_requests", context: context)
RecordingStudioAdmin.resolve_section(key: "root", context: context)
RecordingStudioAdmin.resolve_widget(key: "api_requests.widgets.activity_last_24_hours", context: context)
```

Registries are idempotent for the same key/class pair and raise conflicts for different definitions with the same key.

Availability APIs use the current recording plus section-enablement rules to decide what should appear in navigation or search:

```ruby
RecordingStudioAdmin.available_sections(context: context, recording: recording, placement: :root)
RecordingStudioAdmin.available_admin_items(
  context: context,
  recording: recording,
  placement: :descendant,
  parent: "root",
  include: %i[sections screens]
)
RecordingStudioAdmin.enabled_admin_section_keys(recording: recording, context: context)
```

For an end-to-end reference, use the dummy app initializer at `test/dummy/config/initializers/recording_studio_admin.rb`. It shows:

- multiple screen definitions with charts, table filters, row actions, and widgets
- section definitions that reuse screen widgets
- `recordable` declarations for section-backed RecordingStudio objects
- safe registration from `Rails.application.config.to_prepare`

## Sections, screens, and widgets

Sections are summary pages that define titles, subtitles, FlatPack button links, and widgets. They do not own screens directly.

When you include a widget in a section, you can set a display-level `view_variant` without changing the widget definition itself:

```ruby
class ApiCallsAdminSection < RecordingStudioAdmin::Section
  key "api_calls"

  widget "api_requests.widgets.activity_last_24_hours", view_variant: :compact
end
```

Supported section widget view variants are `:card` and `:compact`.

Sections can also declare an optional RecordingStudio-backed recordable. This keeps section enablement, the admin UI route, and access control separate: `recording_studio_admin_sections` decides whether a recordable type exposes a section, `/admin/sections/:key` renders the section page, and the engine checks the mandatory current context access recording before creating or resolving the section's backing `recordable` and `recording`.

```ruby
class ApiCallsAdminSection < RecordingStudioAdmin::Section
  key "api_calls"
  title "API calls"

  recordable ApiCallsAdminArea,
             find_or_create_by: -> { { key: "api_calls" } },
             parent: -> { AdminRoot.find_or_create_by!(name: "Admin") }
end
```

The backing class is app-owned or supplied by a third-party gem and must be a configured RecordingStudio recordable:

```ruby
class ApiCallsAdminArea < ApplicationRecord
  include RecordingStudio::Recordable
  include RecordingStudioAccessible::AllowsAccessibleChildren

  recording_studio_recordable label: "API calls admin", root: false, allowed_parent_types: [ "AdminRoot" ]
  recording_studio_accessible_children :access
end
```

Add that model to the host app's `RecordingStudio.configure` `recordable_types` list. Third-party generators should create the backing model, migration, section class, and initializer registration, then let the host app enable that section on the recordable types where it should appear.

Reusable gems should define sections and screens without assuming a host-app parent. The host app owns placement through `recording_studio_admin_sections`, while definitions can limit whether they appear for root recordings, descendant recordings, or both:

```ruby
class TeamSection < RecordingStudioAdmin::Section
  key "team"
  title "Team"
  availability_scope :descendant
end

class UsersScreen < RecordingStudioAdmin::Screen
  key "users"
  title "Users"
  availability_scope :descendant
end

class Workspace < ApplicationRecord
  include RecordingStudioAdmin::AllowsAdminSections

  recording_studio_admin_sections do
    section :team
  end
end
```

Screens define detailed pages with main filters, charts, table filters, sortable/paginated tables, and widgets exposed to sections.

Every screen resolves a default summary from its filtered query relation:

- metric: count of records matching the active chart/table filters
- change: percent change against the previous equivalent date range when a date range filter is present
- period: label for the active date range

Customize the summary when the default label or trend semantics need to differ:

```ruby
summary do
  label "Total errors"
  change_good_when :down
end
```

Screens can hide individual summary parts:

```ruby
summary do
  hide_metric
  hide_change
  hide_period
end
```

Widgets support four rendered types:

- `number`: numeric summary cards with `value` and optional `change`
- `list`: list cards with `items`
- `chart`: embedded charts with `chart_type`, `series`, and optional `chart_options`
- `progress`: progress bars with metadata-backed `progress_value`, optional `progress_max`, and optional `progress_label`

`number` and `chart` widgets can set `change_good_when` to control trend semantics:

- `:up` (default): positive change is styled as good
- `:down`: negative change is styled as good (useful for churn or error rates)
- `:neutral`: change text is always styled neutral

Widgets can also call `hide_metric`, `hide_change`, or `hide_period` to suppress those header fields.

Widget field semantics stay separate:

- `subtitle` is descriptive copy
- `metadata[:period_label]` is the reporting window
- `metadata[:unit_label]` is the metric unit
- `progress` widgets use metadata keys such as `:progress_value`, `:progress_max`, `:progress_label`, and `:progress_variant`

Legacy `stat` widget definitions are normalized to `number` for compatibility.

Screen-provided widget keys always include `.widgets.`:

```text
api_requests.widgets.activity_last_24_hours
api_errors.widgets.recent_failures
```

Standalone widgets use:

```text
widgets.system_health
```

Use sections for overview and navigation. Use screens for the full analytical surface. Keep business queries in screen definitions or extracted app services instead of controllers or ERB.

## Filters and table safety

Main filters apply to chart and table queries. Table filters apply only to table results.

Built-in filters include:

- date range
- group by (`hour`, `day`, `week`, `month`, `year`)

Widget-oriented helper methods on `RecordingStudioAdmin::Context` let sections reuse screen widgets while preserving date semantics:

```ruby
context.widget_period_label(default_preset_key: :this_week)
context.widget_time_range(default_preset_key: :this_week)
context.widget_filter_params(default_preset_key: :this_week, preset_param: :date_range_preset)
```

Availability helpers also live on the context, which keeps view and controller code aligned with the current access recording by default:

```ruby
context.available_admin_sections(placement: :root)
context.available_admin_items(placement: :all, include: %i[sections screens])
```

Mounted controllers also expose helper methods for safe navigation back to host-app pages:

```ruby
preserve_anchor_url(section.url)
page_nav_anchor_url(default: "/")
widget_link_url(widget.link_to)
```

Table sorting is restricted to declared sortable columns and directions are limited to `asc` or `desc`.

## Query and table metadata

Resolver results expose structured metadata for future non-HTML consumers:

- `context.query_result`: main-filtered relation count and percent-change fields
- `context.table_result`: rows, total count, page, per-page, total pages, sort, and direction

Formatting belongs in FlatPack views/components, not in definition objects.

## FlatPack UI

All shipped rendering uses FlatPack components. Wrapper views may compose FlatPack, but this gem does not provide a separate UI system.

## Generators

Install the engine:

```bash
bin/rails generate recording_studio_admin:install
```

Generate optional host-app admin root scaffolding:

```bash
bin/rails generate recording_studio_admin:admin_root
```

The admin root generator creates editable app-owned files including `Admin::BaseController`, `AdminRoot`, admin views, layout, and an `admin_roots` migration.

## Documentation map

- Admin screens guide: practical setup and DSL guide for screens, sections, widgets, and registration
- Installation guide: host-app installation and generator behavior
- Configuration guide: initializer options, access recording patterns, and runtime wiring

## Dummy app

The dummy app mounts `RecordingStudioAdmin::Engine` at `/admin`, registers a root summary section, and demonstrates four screens:

- API Requests
- API Errors
- Users
- Background Jobs

Seed data supports date filters, group-by charts, sorting, pagination, and summary widgets.

## Future API readiness

`RecordingStudioApi` integration is intentionally not implemented in v1. Resolver APIs return structured objects so a future API layer can call `RecordingStudioAdmin.resolve_screen`, `resolve_section`, and `resolve_widget` without rendering HTML.
