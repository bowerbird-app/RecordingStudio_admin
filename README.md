# RecordingStudioAdmin

`RecordingStudioAdmin` is the canonical Rails engine for reusable Recording Studio admin and reporting screens.

It provides two separate capabilities:

- **Admin root scaffolding**: optional, generated host-app files for an editable sitewide admin root recordable.
- **Reusable admin screen engine**: code-defined sections, screens, widgets, filters, charts, tables, and resolvers that can be mounted anywhere.

The old admin gem is not an implementation guide for this replacement.

## Requirements

- Rails 8.1+
- RecordingStudio
- RecordingStudioAccessible
- FlatPack

`RecordingStudioAccessible` is required. The generated admin root includes `RecordingStudioAccessible::AllowsAccessibleChildren` by default.

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
/admin/sections/:key
/admin/screens/:key
```

There are no catch-all routes.

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

Sections can also declare an optional RecordingStudio-backed recordable. This keeps the admin UI route separate from access control: `/admin/sections/:key` renders the section page, while the engine checks the mandatory current context access recording before creating or resolving the section's backing `recordable` and `recording`.

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

Add that model to the host app's `RecordingStudio.configure` `recordable_types` list. Third-party generators should create the backing model, migration, section class, and initializer registration, then point navigation at `context.admin_section_path("api_calls")` or the mounted engine's `section_path` helper.

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

## Filters and table safety

Main filters apply to chart and table queries. Table filters apply only to table results.

Built-in filters include:

- date range
- group by (`hour`, `day`, `week`, `month`, `year`)

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

## Dummy app

The dummy app mounts `RecordingStudioAdmin::Engine` at `/admin`, registers a root summary section, and demonstrates four screens:

- API Requests
- API Errors
- Users
- Background Jobs

Seed data supports date filters, group-by charts, sorting, pagination, and summary widgets.

## Future API readiness

`RecordingStudioApi` integration is intentionally not implemented in v1. Resolver APIs return structured objects so a future API layer can call `RecordingStudioAdmin.resolve_screen`, `resolve_section`, and `resolve_widget` without rendering HTML.
