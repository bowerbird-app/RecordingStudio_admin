# RecordingStudioAdmin configuration

`RecordingStudioAdmin` is configured in Ruby through `RecordingStudioAdmin.configure`. There is no YAML loader or `config.x` integration in this engine today.

## Recommended initializer

```ruby
RecordingStudioAdmin.configure do |config|
  config.default_mount_path = "/admin"
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
| `authentication_method` | `:authenticate_user!` | Controller method called before each engine request |
| `current_actor_method` | `:current_user` | Controller method used to resolve the current actor |
| `access_recording_method` | `:recording_studio_admin_access_recording` | Optional controller method fallback when no resolver is configured |
| `access_recording_resolver` | `nil` | Preferred callable for resolving the current `RecordingStudio::Recording` |
| `admin_sections_resolver` | `nil` | Optional callable that returns enabled admin section keys for a recording, replacing recordable declarations |
| `required_access_role` | `:view` | Role passed into `RecordingStudioAccessible.authorized?` |
| `max_page` | `1000` | Hard ceiling for table pagination page numbers |

## Authentication and actor lookup

Every request to the engine runs through `RecordingStudioAdmin::ApplicationController`.

Request flow:

1. call `authentication_method`
2. resolve the current actor with `current_actor_method`
3. build a `RecordingStudioAdmin::Context`
4. resolve the access recording
5. authorize the actor against that recording

If the configured authentication method does not exist on the controller stack, the engine returns `401 Unauthorized`.

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

These methods prefer mounted route helpers when present. If route helpers are unavailable, they fall back to `default_mount_path`.

That means `default_mount_path` should match the route mount you use in the host app.

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
RecordingStudioAdmin.resolve_widget(key: "api_requests.widgets.api_activity", context: context)
RecordingStudioAdmin.resolve_sections(context: context)
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
