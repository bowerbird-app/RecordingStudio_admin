# RecordingStudioAdmin screens, sections, resources, and widgets

This guide explains the practical host-app workflow for building admin UI with `RecordingStudioAdmin`.

## Mental model

There are four main definition types:

- `RecordingStudioAdmin::Screen`: a detailed analytics page with a query, filters, chart, table, summary, and optional referenced standalone widgets
- `RecordingStudioAdmin::Section`: an overview page with links plus standalone widgets referenced by key
- `RecordingStudioAdmin::Resource`: a registry for admin actions that are backed by host-app controllers and authorized through an owning admin section
- `RecordingStudioAdmin::Widget`: a reusable card rendered inside a screen or section

Think of a section as the landing page for an admin area, a screen as the deeper analytical view behind that landing page, and a resource as the action registry that lets rows link into host-owned mutation flows.

## Blast radius

Use `blast_radius` to make wide-scope admin behavior explicit in code review and enforceable at runtime. `RecordingStudioAccessible` still decides whether the actor can access the current recording; `blast_radius` describes how far the definition itself is allowed to reach.

```ruby
class Users < RecordingStudioAdmin::Screen
  key "users"
  blast_radius :site
end

class WorkspaceStats < RecordingStudioAdmin::Screen
  key "workspace_stats"
  blast_radius :root
end
```

Supported values are `:recording`, `:root`, and `:site`. The default is `:recording`.

`blast_radius :site` requires `config.site_admin_recording_resolver` to return the same recording as the current access recording. Site-wide widgets and admin actions are also blocked when they are accidentally placed inside recording- or root-scoped containers.

```ruby
action :flag_email,
       text: "Flag email",
       method: :post,
       blast_radius: :site,
       url: ->(row, context) { context.controller.main_app.flag_email_admin_user_path(row) }
```

## Setup flow

A complete host-app integration usually looks like this:

1. Mount the engine and configure access recording resolution
2. Define one or more screen classes
3. Define one or more section classes
4. Optionally define resource classes for registered admin actions
5. Load the admin definition tree, then register capabilities from `Rails.application.config.to_prepare`
6. Link between pages with `context.admin_screen_path`, `context.admin_section_path`, and registered admin actions

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
    allow_export required_role: :admin

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

    widget "widgets.api_requests.api_activity"
  end

  ApiRequestsActivityWidget = RecordingStudioAdmin::Widget.new("widgets.api_requests.api_activity") do
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
```

## Table exports

Screens can opt into dynamic table exports with `allow_export`. When enabled, the table export button issues a short-lived RecordingStudioExportable trusted export token after the normal admin authentication, access-recording authorization, blast-radius, and screen visibility checks have already passed.

```ruby
class ApiRequests < RecordingStudioAdmin::Screen
  key "api_requests"
  allow_export required_role: :admin

  query { |_context| ApiRequest.all }

  table do
    column :created_at
    column :method
    column :status
    column :path
    default_columns :created_at, :method, :status, :path
  end
end
```

The exported CSV uses the currently selected table columns and the active filters. Existing table-level `export "some.key"` definitions still work for pre-registered RecordingStudioExportable exports.

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

    widget "widgets.api_requests.api_activity", view_variant: :compact
  end
end
```

## Minimal registered action example

Resources register host-owned admin actions. They must belong to a section; authorization is checked against that admin section/access recording and the action's required role, not against the record being edited. Read actions use the configured admin role by default; non-GET or destructive actions require `:admin` by default, and GET links that back a later mutation should declare `required_role: :admin`. The host app still owns the route, controller action, strong params, view, and tests for the edit.

```ruby
module AdminScreens
  class UsersResource < RecordingStudioAdmin::Resource
    key "users"
    section "users"
    title "Manage users"
    subtitle "Edit user account details"

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
  end
end
```

Link to the registered action from a screen table row:

```ruby
table do
  column :email

  admin_action "users.edit", as: :edit_user
end
```

Authorize the host controller before mutating records:

```ruby
RecordingStudioAdmin.authorize_resource!(
  key: "users",
  action: :edit,
  context: recording_studio_admin_context,
  record: @user,
  audit: true,
  audit_action: :update
)
```

Generated mutating controllers use `perform_recording_studio_admin_action!` so each admin CRUD/action request records one audit event with its final outcome:

```ruby
if perform_recording_studio_admin_action!("users", :edit, @user, audit_action: :update) { @user.update(user_params) }
  redirect_to recording_studio_admin_context.admin_screen_path("users")
else
  render :edit, status: :unprocessable_entity
end
```

Recording Studio events are optional. Add one inside the block when the changed recordable should receive domain history or revert support:

```ruby
perform_recording_studio_admin_action!("pages", :edit, @page, audit_action: :update) do |audit|
  if @page.update(page_params)
    audit.recording_studio_event(recordable: @page, action: "admin.updated")
    true
  else
    false
  end
end
```

Generate the host-owned controller, views, resource definition, and test skeleton when you want a standard show/edit/update flow:

```bash
bin/rails generate recording_studio_admin:resource_form users \
  --model=User \
  --section=users \
  --mount=admin \
  --fields=email:email,name:string
```

That generator creates host-app files for the registered resource action flow while keeping ownership of routes, params, persistence, and authentication in the app:

- `app/admin/users/users/resource.rb`
- `app/controllers/admin/users_controller.rb`
- `app/views/admin/users/show.html.erb`
- `app/views/admin/users/edit.html.erb`
- `test/controllers/admin/users_controller_test.rb`

The generated controller uses the recommended authorization pattern so `update` maps back to the registered `:edit` resource action.

After generating the host-owned files, link back to them from a screen table:

```ruby
table do
  column :email

  admin_action "users.show", as: :show_user
  admin_action "users.edit", as: :edit_user
end
```

When an existing resource needs custom member actions later, add a focused scaffold for the resource definition, host controller, route, and test skeleton:

```bash
bin/rails generate recording_studio_admin:resource_action users flag_email \
  --model=User \
  --section=users \
  --confirm="Flag this email?"
```

That generator appends the new registered action to `app/admin/users/users/resource.rb`, adds the host controller method and a `perform_...!` placeholder hook, adds a focused member route block, and creates a skipped test skeleton for the new action.

## Registering definitions

Keep definitions in app-owned admin capability folders, then reload files from a top-level manifest and register each capability from `Rails.application.config.to_prepare`:

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
    api_errors/
      screen.rb
      chart.rb
      table.rb
      widgets/
        recent_failures.rb
  users/
    manifest.rb
    section.rb
    users/
      screen.rb
      chart.rb
      table.rb
      widgets/
        active_users.rb
        review_completion.rb
```

```ruby
Rails.application.config.to_prepare do
  load Rails.root.join("app/admin/manifest.rb")

  AdminScreens.load!
  AdminScreens::Root.register!
  AdminScreens::Api.register!
  AdminScreens::UsersArea.register!
end
```

That pattern matters because Rails reloads app classes in development. `to_prepare` ensures the registry points at the current class objects. The top-level manifest controls file reloading, while each capability manifest keeps its own `register!` list close to the screens and section it owns.

If the files under `app/admin` are manifest-loaded instead of named for Zeitwerk constants, ignore that folder in `config/application.rb`:

```ruby
Rails.autoloaders.main.ignore(root.join("app/admin"))
```

## Lookup and resolver methods

The top-level module exposes the runtime methods most apps and tests need:

```ruby
RecordingStudioAdmin.register_screen(AdminScreens::ApiRequests)
RecordingStudioAdmin.register_section(AdminScreens::RootSection)
RecordingStudioAdmin.register_resource(AdminScreens::UsersResource)

RecordingStudioAdmin.screen_for("api_requests")
RecordingStudioAdmin.section_for("root")
RecordingStudioAdmin.resource_for("users")
RecordingStudioAdmin.widget_for("widgets.api_requests.api_activity")

RecordingStudioAdmin.resolve_sections(context: context)
RecordingStudioAdmin.resolve_section(key: "root", context: context)
RecordingStudioAdmin.resolve_screen(key: "api_requests", context: context)
RecordingStudioAdmin.authorize_resource!(key: "users", action: :edit, context: context, record: user)
RecordingStudioAdmin.resolve_widget(key: "widgets.api_requests.api_activity", context: context)
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
- widgets referenced from the same analytical surface

## Widget key rules

Widgets use explicit standalone keys namespaced by feature or capability:

```text
widgets.api_requests.api_activity
widgets.users.review_completion
```

When a section or screen wants to show a widget, it references the standalone key:

```ruby
widget "widgets.api_requests.api_activity"
```

## Section widget customization

Sections can customize how a widget is displayed without changing the widget definition itself:

```ruby
widget "widgets.api_requests.api_activity",
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

Other usage-level overrides are applied after the widget resolves, so sections can reuse a shared standalone widget while changing only presentation details such as title, compact layout, or chart type.

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
    section :api
    section :users
    section :jobs
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

Keep that distinction explicit in app code:

- the access recording gates entry to the mounted admin surface
- `recording_studio_admin_sections` or `admin_sections_resolver` decides which registered sections are enabled
- `Section.recordable` creates or resolves the section's own RecordingStudio-backed object after the page is opened

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
RecordingStudioAdmin.available_widgets(
  context: context,
  recording: recording,
  placement: :root,
  include: %i[section_widgets linked_screen_widgets]
)
RecordingStudioAdmin.enabled_admin_section_keys(recording: recording, context: context)
```

`placement` accepts `:all`, `:root`, or `:descendant`. `parent` filters search results down to descendants of a specific available item key.
`available_widgets` returns widget metadata from available sections and linked screens without resolving widget values,
rows, list items, or chart series.

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

Widget rendering helpers accept already-resolved widgets and can be included in custom controllers when you want to
reuse the visual widget views outside the mounted admin controller:

```ruby
widget = RecordingStudioAdmin.resolve_widget(key: "widgets.api_requests.api_activity", context: context)
render_recording_studio_widget(widget)
render_recording_studio_widget_body(widget)
render_recording_studio_chart_widget(widget)
```

Use `render_recording_studio_widget` for the full card, `render_recording_studio_widget_body` for only the type-specific
body partial, and `render_recording_studio_chart_widget` when a custom view only needs the chart visual. Widget
resolution remains separate from rendering, so registered widgets still use the normal admin context and authorization
rules.

## Widget types and summary behavior

The current widget DSL supports four types:

- `:number`
- `:chart`
- `:list`
- `:progress`

`number` widgets require a `value`. `chart` widgets require both `chart_type` and `series`. `list` widgets require
`items`. `progress` widgets require `metadata[:progress_value]` and accept `metadata[:progress_max]`,
`metadata[:progress_label]`, and `metadata[:progress_variant]`.

Widgets can also control header semantics independently of body content:

- `subtitle` is descriptive copy
- `change_good_when` controls positive/negative trend styling
- `hide_metric`, `hide_change`, and `hide_period` suppress header fields
- `metadata[:period_label]` and `metadata[:unit_label]` control period and unit copy used by the shared widget views

Screen summaries are separate from widgets. Each screen resolves a summary from its filtered relation, and the summary
DSL can override the label, value source, previous value source, or change semantics when the default count-based
behavior is not the right user-facing summary.

## Resolver APIs

The engine exposes resolver methods that return structured result objects:

```ruby
RecordingStudioAdmin.resolve_screen(key: "api_requests", context: context)
RecordingStudioAdmin.resolve_section(key: "root", context: context)
RecordingStudioAdmin.resolve_widget(key: "widgets.api_requests.api_activity", context: context)
RecordingStudioAdmin.resolve_sections(context: context)
```

That is the API to use in tests, future non-HTML integrations, or internal debugging.

## Suggested host-app layout

```text
app/
  admin/
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
          monthly_api_usage.rb
      api_errors/
        screen.rb
        chart.rb
        table.rb
        widgets/
          recent_failures.rb
    users/
      manifest.rb
      section.rb
      users/
        screen.rb
        chart.rb
        table.rb
        widgets/
          active_users.rb
          review_completion.rb
    root/
      manifest.rb
      section.rb
config/
  initializers/
    recording_studio_admin.rb
```

Keep definitions in app-owned classes grouped by admin capability. Keep configuration and the top-level manifest call in the initializer.

## Common mistakes

| Mistake | Why it causes problems |
|---------|------------------------|
| Registering screens at file load time | development reloads can leave stale definitions in the registry |
| Hard-coding `/admin/screens/...` links | custom mount paths and route helper fallbacks drift |
| Putting query logic in controllers | the engine expects screen definitions and resolvers to own that behavior |
| Confusing the section recordable with the access recording | authorization and section ownership are separate concerns |
| Reaching into views to format or compute data | formatting belongs in views, but query structure belongs in definitions or app services |

## Best reference in this repository

The dummy app admin folders are the best real example to copy from:

- `test/dummy/app/admin`
- `test/dummy/app/admin/manifest.rb`
- `test/dummy/config/initializers/recording_studio_admin.rb`

It includes:

- top-level manifest loading plus per-capability `register!` entrypoints
- multiple screen types
- screen charts and tables split into per-screen `chart.rb` and `table.rb` files
- referenced standalone widgets split into per-screen `widgets/*.rb` files
- referenced standalone widgets
- section links
- section recordables
- `to_prepare` registration
