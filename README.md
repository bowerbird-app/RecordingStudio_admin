# RecordingStudioAdmin

`RecordingStudioAdmin` is the canonical Rails engine for reusable Recording Studio admin and reporting screens.

It provides two separate capabilities:

- **Admin root scaffolding**: optional, generated host-app files for an editable sitewide admin root recordable.
- **Reusable admin screen engine**: code-defined sections, screens, registered admin actions, widgets, filters, charts, tables, and resolvers that can be mounted anywhere.

The old admin gem is not an implementation guide for this replacement.

## Upgrading

Admin `2.7.2` is a housekeeping patch on `2.7.1`. Runtime requirements are in [Requirements](#requirements). Compact widgets stack the title above the metric and clip the mini chart to its box. Full widget cards share `h-[26rem]`, with a 200px chart and at most 5 list items. `config.engine_layout` is now `config.layout`. Page titles use `content_for :title` and `:subtitle`. Back and close use `flat_pack_page_nav`. Page actions use `register_page_nav`. See [docs/UPGRADING.md](docs/UPGRADING.md#upgrading-to-271).

Hosts moving from Admin `1.x` (Accessible `~> 0.3`, RecordingStudio 3.x) to `2.0.0` should follow [docs/UPGRADING.md](docs/UPGRADING.md). That release requires Accessible `~> 0.6` and RecordingStudio `~> 4.1`.

Admin `2.3.0` adds RecordingStudioTrashable `~> 0.10` (query-only) and replaces
`trashed_at: nil` filters with `recording_studio_trashable_kept_sql`. See
[docs/UPGRADING.md](docs/UPGRADING.md#upgrading-to-230).

Admin `2.4.0` requires Flatpack `~> 0.1.254` (git tag `v0.1.254`). Hosts'
own Card `style: :outlined` overrides must move to `border: :strong`. See
[docs/UPGRADING.md](docs/UPGRADING.md#upgrading-to-240).

Admin `2.5.0` fills empty buckets in `AdminActivityLogsSupport.date_series`
(zeros for missing hours/days/weeks/months/years in the selected range). The
method signature is unchanged. See
[docs/UPGRADING.md](docs/UPGRADING.md#upgrading-to-250).

Admin `2.5.1` keeps the Admin activity overview widget on the Admin activity
logs section (not the screen) and shows Date range / Group by inline on that
screen. See [docs/UPGRADING.md](docs/UPGRADING.md#upgrading-to-251).

Admin `2.6.0` registers the host `admin_audit_logs` table with
RecordingStudioLogs. Existing rows stay. There is no summary table. Retention
stays `:indefinite` because RS_Logs does not clean a log with no summaries.
The current Logs constraint is `>= 0.4.1, < 1.0` (development and dummy pin
`v0.7.0`). See [docs/UPGRADING.md](docs/UPGRADING.md#upgrading-to-260).

## Quick start

1. Add the gem to the host app and run the install generator:

```bash
bin/rails generate recording_studio_admin:install
```

2. Mount an admin surface, usually at `/admin`:

```ruby
mount RecordingStudioAccessible::Engine, at: "/admin/access"
recording_studio_admin_for :admin, at: "/admin", root_section: :root
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

4. Define screens and sections in app-owned admin capability folders, then load and register those capabilities from a `to_prepare` block so development reloads stay correct:

```text
app/admin/
  manifest.rb
  api/
    manifest.rb
    section.rb
    api_requests/
      screen.rb
      chart.rb
      table.rb
      widgets/
        api_activity.rb
  root/
    manifest.rb
    section.rb
```

```ruby
module AdminScreens
  def self.load!
    # Load or reload app/admin definition files here.
  end

  def self.register!
    Root.register!
    Api.register!
  end

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

    widget "widgets.api_requests.api_activity"
  end

  ApiRequestsActivityWidget = RecordingStudioAdmin::Widget.new("widgets.api_requests.api_activity") do
    type :number
    title "API activity"
    value { |context| context.query_result.count }
    link_to { |context| context.admin_screen_path("api_requests") }
  end

  class RootSection < RecordingStudioAdmin::Section
    key "root"
    title "Admin summary"
    link :requests, text: "View API requests", url: ->(context) { context.admin_screen_path("api_requests") }
    widget "widgets.api_requests.api_activity", view_variant: :compact
  end
end

Rails.application.config.to_prepare do
  load Rails.root.join("app/admin/manifest.rb")

  AdminScreens.load!
  RecordingStudioAdmin.register_widget(AdminScreens::ApiRequestsActivityWidget)
  AdminScreens.register!
end
```

If the files under `app/admin` are manifest-loaded instead of named for Zeitwerk constants, ignore that folder in `config/application.rb`:

```ruby
Rails.autoloaders.main.ignore(root.join("app/admin"))
```

The dummy app keeps one top-level `app/admin/manifest.rb` for file reloading, plus one `manifest.rb` per capability folder for `register!` calls.

5. Link to screens and sections with the context helpers:

```ruby
context.admin_screen_path("api_requests")
context.admin_section_path("root")
context.admin_sections_path
```

Resources register admin actions that can be linked from screen tables while keeping authorization tied to the owning admin section. Read actions use the configured admin role by default; non-GET or destructive actions require `:admin` by default, and GET links that back a later mutation should declare `required_role: :admin`. The host app owns the controller, route, view, params, and tests for the mutation itself:

```ruby
class AdminScreens::UsersResource < RecordingStudioAdmin::Resource
  key "users"
  section "users"

  action :edit,
         text: "Edit user",
         icon: "pencil-square",
         url: lambda { |row, context|
           user = User.find_by(email: row.email)
           context.controller.main_app.edit_admin_user_path(user) if user
         },
         required_role: :admin

  action :flag_email,
         text: "Flag email",
         icon: "flag",
         method: :post,
         confirm: ->(row, _context) { "Flag #{row.email}?" },
         url: lambda { |row, context|
           user = User.find_by(email: row.email)
           context.controller.main_app.flag_email_admin_user_path(user) if user
         }
end
```

Host controllers call `RecordingStudioAdmin.authorize_resource!(key: "users", action: :edit, context: recording_studio_admin_context, record: @user, audit: true, audit_action: :update)` before changing records. That check authorizes against the resource's owning admin section/access recording and the action's `required_role`, not the edited record.

Mutating host controllers should wrap the change with `perform_recording_studio_admin_action!`. The wrapper emits one admin audit event with a final outcome such as `performed`, `validation_failed`, `failed`, or `denied`; configure `RecordingStudioAdmin.configuration.admin_action_auditor` to write those events to a dedicated audit/log database. Recording Studio events are optional and can be added inside the block when the changed recordable should receive domain history or revert support.

The generated host-app admin root page can also list and search the currently available admin destinations:

```ruby
sections = recording_studio_admin_context.available_admin_sections(
  recording: recording_studio_admin_access_recording
)

items = recording_studio_admin_context.available_admin_items(
  recording: recording_studio_admin_access_recording,
  include: %i[sections screens]
)

widgets = recording_studio_admin_context.available_admin_widgets(
  recording: recording_studio_admin_access_recording,
  include: %i[section_widgets linked_screen_widgets]
)
```

## Requirements

Runtime (gemspec):

- Ruby `>= 3.3.0`
- Rails `~> 8.1.0`
- RecordingStudio `>= 6.1.0`
- RecordingStudioAccessible `~> 0.6`
- RecordingStudioLogs `>= 0.4.1, < 1.0`
- RecordingStudioTrashable `~> 0.10`
- FlatPack `>= 0.1.315`
- view_component `>= 4.14, < 5`

Development and dummy Gemfile pins:

- RecordingStudio `v6.1.0`
- Accessible `v0.21.0`
- Logs `v0.7.0`
- Trashable `v0.12.0` (`require: false` in the root Gemfile)
- Metrics `v0.6.1` (`require: false` in the root Gemfile)
- Flatpack git commit `1fcbafe94f8eb118f0a22182f63f5110fcc97a56` (`0.1.319`)
- `view_component` `4.19.0`

`RecordingStudioAccessible` is required. Enable Accessible on the admin root (and any other recordable that should hold grants) with `RecordingStudio.enable_capability(:accessible, on: self)`. Keep the admin root owned (`shared: false`).

Recordable types opt into admin sections with `RecordingStudioAdmin::AllowsAdminSections`:

```ruby
class AdminRoot < ApplicationRecord
  include RecordingStudio::Recordable
  include RecordingStudioAdmin::AllowsAdminSections

  recording_studio_recordable label: "Admin", root: true, shared: false
  RecordingStudio.enable_capability(:accessible, on: self)

  recording_studio_admin_sections do
    section :root
    section :api
    section :users
    section :jobs
  end
end
```

For the first staff grant on an empty owned admin root, use Accessible bootstrap (no ENV authorizer):

```ruby
RecordingStudioAccessible.bootstrap_owner_access!(
  recording: RecordingStudio.root_recording_for(admin_root),
  actor: first_staff_user
)
```

After that, continue with `grant_access` for additional staff. Configure `access_actor_types` in the Accessible initializer.

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

## Routing and surfaces

Mount the screen engine wherever you need admin or reporting screens. Prefer `recording_studio_admin_for` for new apps; it mounts the engine and registers a named surface in one step:

```ruby
mount RecordingStudioAccessible::Engine, at: "/admin/access"
recording_studio_admin_for :admin, at: "/admin", root_section: :root
```

A surface is a route entrypoint for a specific admin/reporting experience. Definitions stay globally registered, while the surface resolves the current access recording and that recording's recordable type decides which section keys are enabled.

Different surfaces can expose different recordables and section sets:

```ruby
mount RecordingStudioAccessible::Engine, at: "/admin/access"
recording_studio_admin_for :admin, at: "/admin", root_section: :root
recording_studio_admin_for :stats, at: "/stats", root_section: :page_views

RecordingStudioAdmin.configure do |config|
  config.surface :stats do |surface|
    surface.authentication_method = :authenticate_user!
    surface.current_actor_method = :current_user
    surface.access_recording_resolver = ->(context) { context.controller.current_user_recording }
    surface.layout = "application" # optional: override RecordingStudio's default layout
  end
end
```

By default, mounted admin sections and screens use RecordingStudio core's shared `recording_studio/default_layout`.
Set `config.layout` globally or `surface.layout` per surface when the host app should supply its own
layout instead. `nil` falls through to `RecordingStudio.configuration.layout`, then that default name.
`false` renders no layout. A callable is invoked as `call(controller:)`.

For legacy or minimal setup, mounting the engine directly still works:

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

The surface root resolves that surface's `root_section`, which defaults to `root`. If the configured root section is not registered or not enabled for the current recordable, the request returns `404 Not Found` or `403 Forbidden` depending on the failure path.

There are no catch-all routes.

### Frame endpoints

Screens load their chart, table, row count, and widgets through Turbo Frames, so the engine also routes the endpoints those frames fetch:

```text
/admin/screens/:key/chart
/admin/screens/:key/table
/admin/screens/:key/table_count
/admin/screens/:screen_key/widgets/:widget_key
/admin/sections/:section_key/widgets/:widget_key
```

These answer with a bare partial and no layout, because Turbo splices the response into a frame on a page that is already rendered. Loading one as a whole page — typing the URL, opening a bookmark, refreshing, or opening a frame in a new tab — redirects to the screen or section page that owns the frame, carrying the query string across so sort, filters, page, and columns are preserved.

The engine treats a request as a page load when the browser sends `Sec-Fetch-Dest: document`, which happens only for top-level navigation. Turbo Frame loads, XHR, and server-side requests never set it, so anything fetching these endpoints programmatically keeps receiving the partial.

## How admin screens are assembled

The engine is driven by three definition types:

- `RecordingStudioAdmin::Screen`: a detailed page with a query, main filters, chart, table, summary, and referenced standalone widgets.
- `RecordingStudioAdmin::Section`: a summary page with links plus a collection of standalone widgets referenced by key.
- `RecordingStudioAdmin::Widget`: a reusable card definition rendered either inside screens or sections.

The runtime flow is:

1. The controller builds a `RecordingStudioAdmin::Context` from request params, the current actor, route helpers, and view context.
2. The engine resolves the current surface, authenticates the request, and resolves the current access recording.
3. A resolver (`resolve_screen`, `resolve_section`, `resolve_widget`, or `resolve_sections`) turns the code definition into structured result objects.
4. FlatPack-based views render those result objects.

This means host apps own the query logic and admin information architecture in Ruby, while the engine owns routing, authorization checks, resolver orchestration, and rendering.

## Access, enablement, and section ownership

The refactored engine keeps three separate concerns apart:

- access recording: which `RecordingStudio::Recording` gates use of the mounted admin UI
- enabled admin sections: which registered sections should appear for the current recording's recordable type
- section recordable: the optional RecordingStudio-backed object created or resolved after a section page is opened
- blast radius: how widely a definition is allowed to read or mutate data once the actor is authorized

Those concerns often point at related data, but they are not interchangeable.

Use `blast_radius` to mark definitions whose data exposure or mutations extend beyond the current access recording:

```ruby
class UsersScreen < RecordingStudioAdmin::Screen
  key "users"
  blast_radius :site
end

class WorkspaceStats < RecordingStudioAdmin::Screen
  key "workspace_stats"
  blast_radius :root
end
```

`blast_radius :site` definitions require a nominated site admin recording:

```ruby
RecordingStudioAdmin.configure do |config|
  config.site_admin_recording_resolver = lambda do |_context|
    admin_root = AdminRoot.find_by(name: "Admin")
    next unless admin_root

    RecordingStudio::Recording.where(
      RecordingStudio::Recording.recording_studio_trashable_kept_sql
    ).find_by(recordable: admin_root)
  end
end
```

Supported values are `:recording`, `:root`, and `:site`; the default is `:recording`. Nested widgets and admin actions cannot resolve with a wider blast radius than their containing section, screen, or resource.

## Definitions and resolvers

Sections, screens, widgets, filters, charts, and tables are code-defined. Controllers and views consume structured resolver results; they do not own query or rendering logic.

```ruby
RecordingStudioAdmin.register_screen(ApiRequestsScreen)
RecordingStudioAdmin.register_section(AdminRootSection)

RecordingStudioAdmin.resolve_screen(key: "api_requests", context: context)
RecordingStudioAdmin.resolve_section(key: "root", context: context)
RecordingStudioAdmin.resolve_widget(key: "widgets.api_requests.activity_last_24_hours", context: context)
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

For an end-to-end reference, use the dummy app admin definition folders under `test/dummy/app/admin` plus the initializer at `test/dummy/config/initializers/recording_studio_admin.rb`. They show:

- a top-level manifest that reloads definition files plus per-capability `register!` methods
- multiple screen definitions with charts, table filters, row actions, and widgets
- screen charts and tables split into per-screen `chart.rb` and `table.rb` files
- referenced standalone widgets split into per-screen `widgets/*.rb` files
- section definitions that reference standalone widgets
- `recordable` declarations for section-backed RecordingStudio objects
- safe registration from `Rails.application.config.to_prepare`

## Sections, screens, and widgets

Sections are summary pages that define titles, subtitles, FlatPack button links, and widgets. They do not own screens directly.

When you include a widget in a section, you can set a display-level `view_variant` without changing the widget definition itself:

```ruby
class ApiCallsAdminSection < RecordingStudioAdmin::Section
  key "api_calls"

  widget "widgets.api_requests.activity_last_24_hours", view_variant: :compact
end
```

Supported section widget view variants are `:card` and `:compact`.

Sections can also override widget presentation or period params at the usage site without changing the shared widget definition:

```ruby
widget "widgets.api_requests.activity_last_24_hours",
       view_variant: :compact,
       title: "Request volume",
       chart_type: :bar,
       chart_options: { height: 180 },
       params: { duration: 7.days, group_by: :day }
```

A `link_to` override directs the widget to a different admin page than the widget's default:

```ruby
widget "widgets.most_common_errors.error_distribution_chart",
       link_to: ->(context) { AdminScreens::Base.widget_link_path(context, screen_key: "api_errors", preset_key: :this_week) }
```

Use those overrides when a section needs a smaller or differently grouped version of a standalone widget.

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

  recording_studio_recordable label: "API calls admin", root: false, allowed_parent_types: [ "AdminRoot" ]
  RecordingStudio.enable_capability(:accessible, on: self)
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
- `description` remains the full-card title tooltip
- `info` is optional contextual help rendered behind an information icon tooltip; it accepts a static value or a block evaluated with the widget context
- `metadata[:period_label]` is the reporting window
- `metadata[:unit_label]` is the metric unit
- `progress` widgets use metadata keys such as `:progress_value`, `:progress_max`, `:progress_label`, and `:progress_variant`

Compact widget cards abbreviate large numeric metric values so they fit in the card header, for example `23635.64`
renders as `23.6K`. The exact formatted value remains available from the metric tooltip.

List widgets accept `items`, while progress widgets require `metadata[:progress_value]` and optionally `metadata[:progress_max]`.

Legacy `stat` widget definitions are normalized to `number` for compatibility.

Widget keys are explicit standalone keys:

```text
widgets.api_requests.activity_last_24_hours
widgets.api_errors.recent_failures
```

Use sections for overview and navigation. Use screens for the full analytical surface. Keep business queries in screen definitions or extracted app services instead of controllers or ERB.

## Filters and table safety

Main filters apply to chart and table queries. Table filters apply only to table results.

Built-in filters include:

- date range
- group by (`hour`, `day`, `week`, `month`, `year`)

Screen filters display inline when there are fewer than three filters. Screens with three or more main and table
filters use a FlatPack modal by default. Override that behavior in the screen definition when needed:

```ruby
filter_presentation :inline # also supports :modal and :auto (the default)
```

To keep the leading filters visible while placing the remaining filters in the FlatPack modal, nominate an
`inline_count`. Filters retain their declaration order, and each form preserves the other form's active values:

```ruby
filter_presentation :modal, inline_count: 2
```

Select filters pass FlatPack select search options through to the component. Use `searchable`, `search_mode`,
`search_param`, and `search_endpoint` with a declared `values` or `options` collection:

```ruby
filter :status,
       options: -> { ApiRequest.distinct.order(:status).pluck(:status) },
       searchable: true,
       search_mode: :remote,
       search_param: :query,
       search_endpoint: "/admin/filter-options/statuses"
```

Widget-oriented helper methods on `RecordingStudioAdmin::Context` let sections reference standalone widgets while preserving date semantics:

```ruby
context.widget_period_label(default_preset_key: :this_week)
context.widget_time_range(default_preset_key: :this_week)
context.widget_filter_params(default_preset_key: :this_week, preset_param: :date_range_preset)
```

The same context object also owns route helper fallbacks, availability helpers, the current surface, and access recording resolution. Keeping links and widget params on `RecordingStudioAdmin::Context` avoids hard-coded mount paths in definitions.

Availability helpers also live on the context, which keeps view and controller code aligned with the current access recording by default:

```ruby
context.available_admin_sections(placement: :root)
context.available_admin_items(placement: :all, include: %i[sections screens])
context.available_admin_widgets(placement: :root, include: :section_widgets)
```

`available_admin_widgets` returns metadata for widgets exposed by available sections or their linked screens. It does
not resolve widget values, list items, rows, or chart series, so it can answer which widgets are available without
running dashboard queries.

Engine screens set the page heading with `content_for :title` and `content_for :subtitle`. The default layout renders that heading once. Back and close go through `flat_pack_page_nav(round: true, style: :default, ...)`. Section links and screen buttons register with `register_page_nav`. Custom markup, such as access avatars, uses `recording_studio_page_nav_right`.

Mounted controllers also expose helper methods for safe navigation back to host-app pages:

```ruby
preserve_anchor_url(section.url)
page_nav_anchor_url(default: "/")
widget_link_url(widget.link_to)
```

Widget rendering helpers accept resolved widgets, so custom controllers can reuse the visual widget views without
inheriting from the admin controller:

```ruby
widget = RecordingStudioAdmin.resolve_widget(key: "widgets.api_requests.api_activity", context: context)
render_recording_studio_widget(widget)
render_recording_studio_widget_body(widget)
render_recording_studio_chart_widget(widget)
```

Include `RecordingStudioAdmin::WidgetRenderingHelper` in custom controllers that need these helpers outside the mounted
admin engine. Resolving registered widgets still uses the normal admin context and authorization rules; the rendering
helpers only handle presentation.

Table sorting is restricted to declared sortable columns and directions are limited to `asc` or `desc`.

## Query and table metadata

Resolver results expose structured metadata for future non-HTML consumers:

- `context.query_result`: main-filtered relation count and percent-change fields
- `context.table_result`: rows, total count, page, per-page, total pages, sort, and direction

Formatting belongs in FlatPack views/components, not in definition objects.

## FlatPack UI

All shipped rendering uses FlatPack components. Wrapper views may compose FlatPack, but this gem does not provide a separate UI system.

### Interface text

Static chrome in the gem's own views (PageNav defaults, sections index copy,
filter/table controls, widget More/info labels), sections search group
headings, and screen date-preset labels passed to Stimulus ship as English
Rails I18n keys under `recording_studio.admin` in `config/locales/en.yml`.
Hosts can override those keys. Titles, subtitles, link labels, and export
button text passed through the admin DSL or `content_for` stay caller-owned.
`Period::QUICK_PRESET_LABELS` and other public return values stay English;
translation happens at the render site. There is no dependency on
`recording_studio_internationalization`.

## Generators

Install the engine:

```bash
bin/rails generate recording_studio_admin:install
```

Generate optional host-app admin root scaffolding:

```bash
bin/rails generate recording_studio_admin:admin_root
```

The admin root generator creates editable app-owned files including `Admin::BaseController`, `AdminRoot`, `AdminAuditLog`, admin views, layout, and `admin_roots` plus `admin_audit_logs` migrations. It also enables the built-in `admin_activity_logs` section so the gem-owned Admin activity logs screen appears for the generated admin root.

Admin registers `AdminAuditLog` with RecordingStudioLogs as an unpartitioned, indefinite raw log (`partition_interval: nil`, `root_column: :root_recording_id`). Existing rows stay in `admin_audit_logs`. The table is not copied or partitioned. There is no summary table and no `aggregate` call. Actor, IP, user agent, request id, and error text stay off the aggregatable allowlist.

`config.logs_retention` defaults to `:indefinite`. Registration always uses `:indefinite`. RecordingStudioLogs does not clean a log with no summaries, so a finite window would sit at "Cleanup waiting". Do not schedule Logs partition or retention jobs for this table. Existing hosts run `bin/rails generate recording_studio_admin:logs` after `recording_studio_logs:migrations` to add `root_recording_id` only.

## Documentation map

- This README: setup, screens, configuration, and dummy app
- Install generator notes: `lib/generators/recording_studio_admin/install/INSTALL.md`
- Upgrade notes: [docs/UPGRADING.md](docs/UPGRADING.md)
- Cloud Agent boot: [Cursor skills in Cloud Agents](docs/cursor-skills.md)

## Dummy app

Dummy credentials (`test/dummy/config/credentials.yml.enc`) are encrypted with the shared RecordingStudio_* development master key. Set `RAILS_MASTER_KEY` or put that key in `test/dummy/config/master.key` (gitignored). Keep the encrypted file; do not generate a per-repo dummy key.

The dummy app mounts `RecordingStudioAdmin::Engine` at `/admin`, registers a root summary section, and demonstrates five screens:

- API Requests
- API Errors
- Admin Activity Logs
- Users
- Background Jobs

Seed data supports date filters, group-by charts, sorting, pagination, and summary widgets.

The dummy pins RecordingStudio `v6.1.0`, Flatpack `0.1.319`, Accessible `v0.21.0`, Logs `v0.7.0`, and Trashable `v0.12.0`. Root switchable stays `v0.8.0`. Access `role` is a string (`view`, `edit`, `admin`). Seeds and tests grant through `RecordingStudioAccessible.bootstrap_owner_access!` and `grant_access`; they do not write `RecordingStudio::Access` rows directly.

## Cloud Agent boot

Cloud Agent Builds run `.cursor/install.sh`, then `.cursor/fetch-skills.sh`.
The install hook provisions a cold image. On a warm snapshot it skips apt,
ruby-build, db:prepare, and tailwind when Ruby, bundle, and Postgres are
already usable. If `RAILS_MASTER_KEY` is set, `install.sh` writes gitignored
`test/dummy/config/master.key` so dummy credentials decrypt. Fetch-skills
always runs last. `.cursor/start.sh` starts PostgreSQL on each boot. Rebuild
with Draft off to load a new pack. See
[Cursor skills in Cloud Agents](docs/cursor-skills.md).

## Future API readiness

`RecordingStudioApi` integration is intentionally not implemented in v1. Resolver APIs return structured objects so a future API layer can call `RecordingStudioAdmin.resolve_screen`, `resolve_section`, and `resolve_widget` without rendering HTML.
