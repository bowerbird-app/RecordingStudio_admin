# RecordingStudioAdmin documentation index

This directory still lives under `docs/gem_template/` because it originated from the shared engine template, but the content should document the current `RecordingStudioAdmin` gem.

## Start here

- [../../README.md](../../README.md): top-level product overview and API summary
- [INSTALLING.md](INSTALLING.md): host-app installation, generator behavior, and the manifest-based registration entrypoint
- [CONFIGURATION.md](CONFIGURATION.md): authentication, actor, surfaces, access-recording, and route helper configuration
- [ADMIN_SCREENS.md](ADMIN_SCREENS.md): capability-folder layout, screen/section/widget DSL, and resolver usage

## Reference guides in this folder

- [CODESPACES.md](CODESPACES.md): devcontainer and Codespaces workflow

The older template-era docs that described generic gem-template hooks, services, migrations, renaming, and other non-RecordingStudioAdmin setup have been removed from this repository.

## Best reference implementation

For a concrete end-to-end example, start with the dummy app:

- `test/dummy/app/admin/manifest.rb`
- `test/dummy/config/initializers/recording_studio_admin.rb`
- `test/dummy/config/routes.rb`

Those files show the real engine integration pattern used in this repository:

- load the admin definition tree from a top-level manifest
- register screens and sections from per-capability `register!` methods
- configure access recording resolution
- define screens, charts, tables, widgets, and sections in app-owned capability folders
- register them from `Rails.application.config.to_prepare`
- mount the engine with `recording_studio_admin_for`

## Notes for AI agents

If you need to understand or extend the admin screen DSL, prioritize these files before exploring wider repo history:

- `lib/recording_studio_admin/screen.rb`
- `lib/recording_studio_admin/section.rb`
- `lib/recording_studio_admin/widget.rb`
- `lib/recording_studio_admin/context.rb`
- `lib/recording_studio_admin/configuration.rb`
- `lib/recording_studio_admin/routing.rb`
- `lib/recording_studio_admin/registry.rb`
- `test/dummy/app/admin/manifest.rb`
- `test/dummy/config/initializers/recording_studio_admin.rb`
