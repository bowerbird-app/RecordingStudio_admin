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
2. Mounts `RecordingStudioAdmin::Engine` at `/admin`
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

The generator adds explicit mounts:

```ruby
mount RecordingStudioAccessible::Engine, at: "/admin/access"
mount RecordingStudioAdmin::Engine, at: "/admin"
```

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

### Tailwind

When `app/assets/tailwind/application.css` exists, the generator injects sources for the engine and FlatPack components:

```css
@source "../../vendor/bundle/**/recording_studio_admin/app/views/**/*.erb";
@source "../../vendor/bundle/**/recording_studio_admin/app/components/**/*.{rb,erb}";
@source "../../vendor/bundle/**/flat_pack/app/components/**/*.{rb,erb}";
```

These are required so Tailwind can see classes used by the engine and FlatPack.

## Manual installation

If you do not want to run the generator, the minimum host-app setup is:

1. Mount `RecordingStudioAccessible::Engine`
2. Mount `RecordingStudioAdmin::Engine`
3. Add a `RecordingStudioAdmin.configure` block
4. Register at least one screen or section from `Rails.application.config.to_prepare`

Example:

```ruby
Rails.application.routes.draw do
  mount RecordingStudioAccessible::Engine, at: "/admin/access"
  mount RecordingStudioAdmin::Engine, at: "/admin"
end
```

```ruby
RecordingStudioAdmin.configure do |config|
  config.authentication_method = :authenticate_user!
  config.current_actor_method = :current_user
  config.access_recording_resolver = ->(context) { context.controller.current_root_recording }
end

Rails.application.config.to_prepare do
  RecordingStudioAdmin.register_screen(AdminScreens::ApiRequests)
  RecordingStudioAdmin.register_section(AdminScreens::RootSection)
end
```

## Register definitions safely

Always register screens and sections from a `to_prepare` block:

```ruby
Rails.application.config.to_prepare do
  RecordingStudioAdmin.register_screen(AdminScreens::ApiRequests)
  RecordingStudioAdmin.register_screen(AdminScreens::Users)
  RecordingStudioAdmin.register_section(AdminScreens::RootSection)
end
```

Why this matters:

- Rails reloads app classes in development
- the registry keeps object identity and key conflict checks
- `to_prepare` ensures the current class objects are registered after reload

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

Use it when the host app needs a real admin root recordable. Do not use it just to define screens; screen and section DSL classes work without the admin root generator.

## Recommended file layout

A practical host-app layout is:

```text
app/
  admin_screens/
    api_requests.rb
    users.rb
    root_section.rb
config/
  initializers/
    recording_studio_admin.rb
```

Keep screen and section definitions in app-owned files. Keep registration in the initializer.

## Reference implementation

The dummy app is the best full-stack example in this repository:

- `test/dummy/config/initializers/recording_studio_admin.rb`
- `test/dummy/config/routes.rb`

It demonstrates:

- access recording resolution
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
