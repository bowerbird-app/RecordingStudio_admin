# Installing RecordingStudioAdmin

This guide covers the host-app steps required to mount `RecordingStudioAdmin`, wire access control, and register screen and section definitions.

## Prerequisites

- Rails 8.1+
- `RecordingStudio`
- `RecordingStudioAccessible`
- `FlatPack`
- A host-app authentication method such as `authenticate_user!`
- A way to resolve the current `RecordingStudio::Recording` that owns the admin context

## Install the gem

Add the gem to the host app, then install dependencies:

```ruby
gem "recording_studio_admin"
```

```bash
bundle install
```

## Run the install generator

```bash
bin/rails generate recording_studio_admin:install
```

By default the generator:

1. Mounts `RecordingStudioAccessible::Engine` at `/admin/access`
2. Mounts a named `RecordingStudioAdmin` surface at `/admin`
3. Creates `config/initializers/recording_studio_admin.rb`
4. Adds Tailwind `@source` entries for RecordingStudioAdmin and FlatPack, when Tailwind is present

The install generator does not create host-app admin screens or views. If the host app also wants the scaffolded
`AdminRoot` model, admin layout, and searchable `/admin/root` page used by the dummy app, run the separate
`recording_studio_admin:admin_root` generator after installation.

Use a different mount path if needed:

```bash
bin/rails generate recording_studio_admin:install --mount_path=/reporting/admin
```

## What the generator writes

### Routes

The generator adds explicit mounts. The `recording_studio_admin_for` helper mounts the engine and registers the route as a named admin surface:

```ruby
mount RecordingStudioAccessible::Engine, at: "/admin/access"
recording_studio_admin_for :admin, at: "/admin"
```

That exact route output relies on the surface default `root_section` of `:root`. Pass `root_section:` yourself only when you want a different surface root.

### Initializer

The generated initializer is intentionally small:

```ruby
RecordingStudioAdmin.configure do |config|
  config.default_mount_path = "/admin"
  config.authentication_method = :authenticate_user!
  config.current_actor_method = :current_user
  config.access_recording_resolver = lambda do |context|
    # Must return the RecordingStudio::Recording for the current admin context.
  end
end

# Rails.application.config.to_prepare do
#   RecordingStudioAdmin.register_screen(MyAdminScreen)
#   RecordingStudioAdmin.register_section(MyAdminSection)
# end
```

That split is deliberate: configuration belongs in `RecordingStudioAdmin.configure`, while screen and section registration should happen inside `Rails.application.config.to_prepare` so development reloads remain safe.

`recording_studio_admin_for` does two things at once:

1. mounts `RecordingStudioAdmin::Engine` at the given path
2. registers a named surface with that path and root section

Per-surface overrides then belong in `config.surface` blocks, not in separate route declarations.

Additional surfaces can be mounted for other recordables without defining routes for each section:

```ruby
recording_studio_admin_for :stats, at: "/stats", root_section: :page_views

RecordingStudioAdmin.configure do |config|
  config.surface :stats do |surface|
    surface.access_recording_resolver = ->(context) { context.controller.current_user_recording }
  end
end
```

The `/stats` surface then exposes whatever sections are enabled on the resolved recording's recordable type.

### Tailwind

When `app/assets/tailwind/application.css` exists, the generator injects sources for the engine and FlatPack components:

```css
@theme inline {
  --color-primary: var(--color-primary);
  --color-primary-hover: var(--color-primary-hover);
  --color-primary-text: var(--color-primary-text);
  --color-danger-background-color: var(--color-danger-background-color);
  --color-danger-text-color: var(--color-danger-text-color);
}

@source "../../vendor/bundle/**/recording_studio_admin/app/views/**/*.erb";
@source "../../vendor/bundle/**/recording_studio_admin/app/components/**/*.{rb,erb}";
@source "../../vendor/bundle/**/flat_pack/app/components/**/*.{rb,erb}";
@source "../../../../../../usr/local/bundle/ruby/**/bundler/gems/flatpack-*/app/components/**/*.{rb,erb}";
```

The `@theme inline` bridge lets Tailwind semantic utilities reuse FlatPack theme tokens, and the extra `/usr/local/bundle` source covers bundled gem paths in containerized installs.

## Manual installation

If you do not want to run the generator, the minimum host-app setup is:

1. Mount `RecordingStudioAccessible::Engine`
2. Mount a `RecordingStudioAdmin` surface
3. Add a `RecordingStudioAdmin.configure` block
4. Register at least one screen or section from `Rails.application.config.to_prepare`

Example:

```ruby
Rails.application.routes.draw do
  mount RecordingStudioAccessible::Engine, at: "/admin/access"
  recording_studio_admin_for :admin, at: "/admin"
end
```

```ruby
RecordingStudioAdmin.configure do |config|
  config.authentication_method = :authenticate_user!
  config.current_actor_method = :current_user
  config.access_recording_resolver = ->(context) { context.controller.current_root_recording }
end

Rails.application.config.to_prepare do
  load Rails.root.join("app/admin/manifest.rb")

  AdminScreens.load!
  AdminScreens::Root.register!
  AdminScreens::Api.register!
end
```

If your app follows the generated initializer template more closely, keep the `to_prepare` block in `config/initializers/recording_studio_admin.rb` instead of introducing a second registration entrypoint.

## Register definitions safely

Always register screens and sections from a `to_prepare` block:

```ruby
Rails.application.config.to_prepare do
  load Rails.root.join("app/admin/manifest.rb")

  AdminScreens.load!
  AdminScreens::Root.register!
  AdminScreens::Api.register!
  AdminScreens::UsersArea.register!
end
```

Why this matters:

- Rails reloads app classes in development
- the registry keeps object identity and key conflict checks
- `to_prepare` ensures the current class objects are registered after reload
- manifest loading keeps per-screen files, widgets, and capability-specific `register!` calls organized together

## Validate the install

After installation, validate these paths:

1. `/admin` resolves the registered `root` section
2. `/admin/sections` lists available sections
3. `/admin/sections/:key` resolves a registered section
4. `/admin/screens/:key` resolves a registered screen
4. `/admin/root` renders the generated host-app admin landing page, if you ran `recording_studio_admin:admin_root`

If authentication is configured incorrectly, requests return `401 Unauthorized`.
If access recording resolution fails or access is denied, requests return `403 Forbidden`.

## Optional admin root scaffolding

If the host app needs editable admin-root recordables and app-owned admin views, run:

```bash
bin/rails generate recording_studio_admin:admin_root
```

This generator creates app-owned scaffolding such as `AdminRoot`, `Admin::BaseController`, admin layout files, and the related migration.

It also creates `AdminAuditLog` storage plus the `admin_audit_logs` migration, and enables the built-in `admin_activity_logs` section on `AdminRoot`. The section, screen, and widget definitions for Admin activity logs stay gem-owned so gem upgrades can update that UI without regenerating host-app files.

Use it when the host app needs a real admin root recordable. Do not use it just to define screens; screen and section DSL classes work without the admin root generator.

## Recommended file layout

A practical host-app layout is:

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

Keep admin definitions in app-owned capability folders. Use the top-level manifest to reload files, and keep the `to_prepare` registration entrypoint in the initializer.

## Reference implementation

The dummy app is the best full-stack example in this repository:

- `test/dummy/app/admin/manifest.rb`
- `test/dummy/config/initializers/recording_studio_admin.rb`
- `test/dummy/config/routes.rb`

It demonstrates:

- access recording resolution
- manifest-based file loading
- per-capability `register!` entrypoints
- multiple screen definitions
- section-backed recordables
- generated admin-root search over sections and screens
- widget reuse across sections
- registration from `to_prepare`

## Troubleshooting

| Issue | What to check |
|-------|----------------|
| `401 Unauthorized` | `authentication_method` exists on the mounted controller stack |
| `403 Forbidden` | `access_recording_resolver` returns a valid recording and the actor has the required role |
| Section or screen returns `404` | the key is registered and the `to_prepare` block is loading |
| Styles are missing | Tailwind `@source` lines include RecordingStudioAdmin and FlatPack |
| Development reloads cause registry conflicts | move registration into `Rails.application.config.to_prepare` |

## Related documentation

- [ADMIN_SCREENS.md](ADMIN_SCREENS.md)
- [CONFIGURATION.md](CONFIGURATION.md)
