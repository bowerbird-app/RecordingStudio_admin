# RecordingStudioAdmin configuration

`RecordingStudioAdmin` is configured in Ruby through `RecordingStudioAdmin.configure`. When `config/recording_studio_admin.yml` exists in the host app, the engine also loads and merges that file at boot.

The refactored gem keeps configuration, routing, and registration separate:

- `RecordingStudioAdmin.configure` owns engine defaults and per-surface overrides
- `recording_studio_admin_for` in routes mounts the engine and registers named surfaces
- `Rails.application.config.to_prepare` owns definition loading and registration

## Recommended initializer

```ruby
RecordingStudioAdmin.configure do |config|
  config.default_mount_path = "/admin"
  config.engine_layout = "application"
  config.authentication_method = :authenticate_user!
  config.current_actor_method = :current_user
  config.required_access_role = :view
  config.max_page = 1_000

  config.access_recording_resolver = lambda do |context|
    context.controller.current_root_recording
  end
end
```

## Configuration options

| Option | Default | Purpose |
|--------|---------|---------|
| `default_mount_path` | `"/admin"` | Fallback path used by `Context#admin_screen_path` and related helpers when route helpers are not available |
| `engine_layout` | `"application"` | Rails layout used by engine controllers (`RecordingStudioAdmin::ApplicationController`) |
| `authentication_method` | `:authenticate_user!` | Controller method called before each engine request |
| `current_actor_method` | `:current_user` | Controller method used to resolve the current actor |
| `access_recording_method` | `:recording_studio_admin_access_recording` | Optional controller method fallback when no resolver is configured |
| `access_recording_resolver` | `nil` | Preferred callable for resolving the current `RecordingStudio::Recording` |
| `site_admin_recording_resolver` | `nil` | Optional callable that nominates the one access recording allowed to resolve `blast_radius :site` definitions |
| `admin_sections_resolver` | `nil` | Optional callable that returns enabled admin section keys for a recording, replacing recordable declarations |
| `admin_action_auditor` | `nil` | Optional callable that receives one `RecordingStudioAdmin::AdminActionAuditEvent` for each audited admin action outcome |
| `required_access_role` | `:view` | Role passed into `RecordingStudioAccessible.authorized?` |
| `max_page` | `1000` | Hard ceiling for table pagination page numbers |

Async widget loading is configured under `config.async_widgets`:

| Async widget option | Default | Purpose |
|--------|---------|---------|
| `enabled` | `true` | Render section/screen widget placeholders on the page request and load each widget through an engine-owned endpoint |
| `max_concurrent_requests` | `4` | Maximum widget frame requests the bundled scheduler starts at once per page |
| `retry_count` | `1` | Reserved retry budget for the scheduler when a widget load fails |

By default, widgets still resolve through their parent section or screen but do so from bounded async frame requests. That keeps authorization, visibility, blast-radius checks, widget usage params, filters, and access recording context centralized while allowing faster widgets to render before slower widgets finish.

```ruby
RecordingStudioAdmin.configure do |config|
  config.async_widgets.enabled = true
  config.async_widgets.max_concurrent_requests = 4
  config.async_widgets.retry_count = 1
end
```

Set `config.async_widgets.enabled = false` only when you need the older behavior where every widget resolves during the initial page response.

Per-surface overrides live under `config.surface(:name)` and support these request-time keys:

| Surface option | Inherits from | Purpose |
|--------|---------|---------|
| `path` | route declaration | Mount path matched for this surface |
| `root_section` | `:root` | Section key resolved by the surface root route |
| `authentication_method` | global configuration | Per-surface authentication hook |
| `current_actor_method` | global configuration | Per-surface actor lookup |
| `access_recording_method` | global configuration | Per-surface controller fallback for access recording lookup |
| `access_recording_resolver` | global configuration | Per-surface callable for access recording lookup |
| `engine_layout` | global configuration | Per-surface layout override |

## Admin surfaces

An admin surface is a named route entrypoint for a specific admin or reporting experience. The route chooses the current surface, the surface resolves an access recording, and that recording's recordable type decides which registered sections appear.

Use `recording_studio_admin_for` in routes:

```ruby
mount RecordingStudioAccessible::Engine, at: "/admin/access"
recording_studio_admin_for :admin, at: "/admin", root_section: :root
recording_studio_admin_for :stats, at: "/stats", root_section: :page_views
```

Then override behavior per surface only where it differs from the global defaults:

```ruby
RecordingStudioAdmin.configure do |config|
  config.surface :stats do |surface|
    surface.authentication_method = :authenticate_user!
    surface.current_actor_method = :current_user
    surface.access_recording_resolver = ->(context) { context.controller.current_user_recording }
    surface.engine_layout = "application"
  end
end
```

Surfaces do not own section definitions. Sections remain globally registered, and recordable classes opt into section keys with `recording_studio_admin_sections`.

The route helper establishes the surface path and root section. The configuration block then overrides request-time behavior such as authentication, actor lookup, access recording resolution, and layout.

## Authentication and actor lookup

Every request to the engine runs through `RecordingStudioAdmin::ApplicationController`.

Request flow:

1. call `authentication_method`
2. resolve the current actor with `current_actor_method`
3. build a `RecordingStudioAdmin::Context`
4. resolve the access recording
5. authorize the actor against that recording

If the configured authentication method does not exist on the controller stack, the engine returns `401 Unauthorized`. A surface can override `authentication_method`, `current_actor_method`, and `engine_layout`; otherwise it inherits the global configuration.

## Access recording resolution

The access recording is mandatory. It determines which `RecordingStudio::Recording` the actor is allowed to inspect while browsing admin screens.

Preferred pattern:

```ruby
RecordingStudioAdmin.configure do |config|
  config.access_recording_resolver = ->(context) { context.controller.current_root_recording }
end
```

Fallback pattern if the host app already exposes a controller method:

```ruby
RecordingStudioAdmin.configure do |config|
  config.access_recording_method = :current_admin_recording
end
```

The resolver can accept:

- zero arguments
- one argument: `context`
- two arguments: `context, controller`

If resolution returns `nil`, or access is denied, the engine returns `403 Forbidden`.

This separation matters because the access recording is not the same thing as the optional section-backed recordable created by `Section.recordable`.

## Admin action audit events

Generated host CRUD controllers and custom resource actions wrap mutating paths with `perform_recording_studio_admin_action!`. The wrapper emits one admin audit event with an `outcome` such as `performed`, `validation_failed`, `failed`, or `denied`. The event is also published through `ActiveSupport::Notifications` as `admin_action.recording_studio_admin`.

Configure `admin_action_auditor` to write these events to a dedicated audit/log database:

The built-in `admin_activity_logs` screen reads from this host-app audit table when the section is enabled on a recordable.

```ruby
RecordingStudioAdmin.configure do |config|
  config.admin_action_auditor = lambda do |event|
    AdminAuditLog.record_admin_action!(event)
  end
end
```

Recording Studio events remain optional domain-history records. Add one from inside the admin action block when the changed item should appear in that recordable's timeline or support app-specific revert workflows:

```ruby
perform_recording_studio_admin_action!("pages", :edit, @page, audit_action: :update) do |audit|
  if @page.update(page_params)
    audit.recording_studio_event(
      recordable: @page,
      action: "admin.updated",
      metadata: { changed_attributes: @page.previous_changes.keys }
    )
    true
  else
    false
  end
end
```

The audit event answers who performed or attempted the admin action. The optional Recording Studio event belongs to the changed recordable and shares the admin audit event id in its metadata.

## Site admin recording and blast radius

`blast_radius` marks how wide a definition is allowed to reach. It is a runtime safety contract, not a replacement for `RecordingStudioAccessible` authorization.

Supported values are:

- `:recording`: the current access recording only; this is the default
- `:root`: the current root/workspace tree
- `:site`: site-wide or cross-root data, including other users' records

Nominate the host-app recording that represents site-wide admin before using `blast_radius :site`:

```ruby
RecordingStudioAdmin.configure do |config|
  config.site_admin_recording_resolver = lambda do |_context|
    admin_root = AdminRoot.find_by(name: "Admin")
    next unless admin_root

    RecordingStudio::Recording.find_by(recordable: admin_root, trashed_at: nil)
  end
end
```

A `:site` screen, section, widget, or resource action resolves only when the current access recording matches this configured site admin recording. Nested definitions cannot have a wider blast radius than their containing screen, section, or resource.

## Required authorization behavior

The engine expects `RecordingStudioAccessible` to be present and uses the configured role when checking access.

Typical default:

```ruby
config.required_access_role = :view
```

Raise the role only when the mounted admin UI should require a stronger permission boundary.

## Route helper behavior

`RecordingStudioAdmin::Context` exposes:

- `admin_screen_path(key)`
- `admin_section_path(key)`
- `admin_sections_path`

These methods prefer mounted route helpers when present. If route helpers are unavailable, they fall back to the current surface path, then `default_mount_path`.

That means `default_mount_path` should match the primary route mount you use in the host app. Additional mounts should be declared as surfaces so fallback paths stay correct for those requests.

## Registration belongs in `to_prepare`

Configuration and registration solve different problems.

Use the initializer for engine options:

```ruby
RecordingStudioAdmin.configure do |config|
  config.authentication_method = :authenticate_user!
end
```

Use `Rails.application.config.to_prepare` for screens and sections:

```ruby
Rails.application.config.to_prepare do
  RecordingStudioAdmin.register_screen(AdminScreens::ApiRequests)
  RecordingStudioAdmin.register_section(AdminScreens::RootSection)
end
```

Do not register definitions directly at file load time in development. The registry is conflict-safe, but development reloads can still produce stale class registration patterns if you bypass `to_prepare`.

## Enabling admin sections on recordables

Registering a section makes the definition available to the engine. It does not automatically show the section for every admin recording. Host apps enable sections on the recordable types that should expose them:

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

The same registered section can be enabled by multiple recordable types. When a page asks for available admin sections for a recording, the engine uses the recording's recordable class to decide which sections are enabled, then applies authorization and visibility checks.

For apps that need central routing logic instead of per-recordable declarations, configure `admin_sections_resolver`:

```ruby
RecordingStudioAdmin.configure do |config|
  config.admin_sections_resolver = lambda do |recording:, recordable:, context:|
    if recordable.is_a?(AdminRoot)
      %i[root users]
    else
      []
    end
  end
end
```

When this resolver is configured, its return value replaces `recording_studio_admin_sections` declarations. Return an empty array to enable no sections for a recording.

The resolver may be defined with keyword arguments or positional arguments. The engine passes `recording`, `recordable`, and `context` so host apps can keep enablement logic centralized without moving section definitions out of their capability folders.

## RecordingStudio-backed sections

Sections may optionally declare a `recordable` block so the section can map to an app-owned RecordingStudio object:

```ruby
class RootSection < RecordingStudioAdmin::Section
  key "root"

  recordable "AdminSection",
             find_or_create_by: -> { { key: "root", name: "Admin section" } },
             parent: -> { AdminRoot.find_or_create_by!(name: "Admin") }
end
```

That is separate from section enablement and from the access recording. `recording_studio_admin_sections` controls whether a section appears for a recordable. The access recording controls whether the user may view the admin UI at all. The section `recordable` controls the section's own backing RecordingStudio object after the section is opened.

## Runtime APIs worth knowing

These are the main entry points for host apps, tests, and future API integrations:

```ruby
RecordingStudioAdmin.register_screen(MyScreen)
RecordingStudioAdmin.register_section(MySection)

RecordingStudioAdmin.resolve_screen(key: "api_requests", context: context)
RecordingStudioAdmin.resolve_section(key: "root", context: context)
RecordingStudioAdmin.resolve_widget(key: "widgets.api_requests.api_activity", context: context)
RecordingStudioAdmin.resolve_sections(context: context)
```

Related context helpers live on `RecordingStudioAdmin::Context`:

```ruby
context.admin_screen_path("api_requests")
context.admin_section_path("root")
context.admin_sections_path

context.widget_period_label(default_preset_key: :this_week)
context.widget_time_range(default_preset_key: :this_week)
context.widget_filter_params(default_preset_key: :this_week)
```

## Troubleshooting

| Problem | Likely cause |
|---------|--------------|
| `401 Unauthorized` | `authentication_method` is missing or not available on the controller |
| `403 Forbidden` | access recording resolution returned `nil` or the actor lacks the required role |
| Generated links point at the wrong base path | `default_mount_path` does not match the real route mount |
| Section widgets link to the current page incorrectly | use `context.admin_screen_path` or `context.admin_section_path` instead of hard-coded paths |

## Reference files

- `lib/recording_studio_admin/configuration.rb`
- `lib/recording_studio_admin/context.rb`
- `app/controllers/recording_studio_admin/application_controller.rb`
- `lib/generators/recording_studio_admin/install/templates/recording_studio_admin_initializer.rb`
