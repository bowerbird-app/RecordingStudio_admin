# Changelog

## Unreleased

## 2.0.0

### ⚠ BREAKING CHANGES

- Requires `recording_studio_accessible ~> 0.6` (and RecordingStudio `~> 4.1` via that stack). Hosts still on Accessible `0.3` must upgrade Accessible and RecordingStudio before installing Admin `2.0.0`.
- Removed the `AllowsAccessibleChildren` / `recording_studio_accessible_children` compatibility bridge. Enable Accessible with `RecordingStudio.enable_capability(:accessible, on: …)` on each recordable that should hold grants.
- Generated `AdminRoot` is an owned root (`shared: false`) and enables `:accessible` via the capability API.

### Added

- Dummy and docs guidance for first-staff seeding with `RecordingStudioAccessible.bootstrap_owner_access!` on an empty owned admin root (no ENV bootstrap authorizer).
- RecordingStudio `4.1` harden indexes migration in the dummy app.

### Changed

- Bumped FlatPack to `~> 0.1.129`.
- Dummy pins: RecordingStudio `v4.1.0`, Accessible `0.6.1` (PR branch until tagged), Root Switchable `v0.5.0`, FlatPack `v0.1.129`.
- Dummy Tailwind sources aligned with sibling dummies so FlatPack / engine classes are included in the build.
- Dummy Accessible initializer sets `access_actor_types = ["User"]`.

### Removed

- Optional `recording_studio_exportable` companion from the dummy Gemfile until that gem supports RecordingStudio `~> 4.1`. Table export demos remain gated behind `defined?(RecordingStudioExportable)`.

### Upgrade Notes

1. Upgrade RecordingStudio to `~> 4.1` and Accessible to `~> 0.6` (prefer `0.6.1` once tagged for `bootstrap_owner_access!`).
2. Replace mixin enablement:

   ```ruby
   # Before
   include RecordingStudioAccessible::AllowsAccessibleChildren
   recording_studio_accessible_children :access

   # After
   RecordingStudio.enable_capability(:accessible, on: self)
   ```

3. Keep AdminRoot owned (`shared: false`). Do not make the admin root a shared root; Accessible refuses new grants on shared roots.
4. Configure `RecordingStudioAccessible.configuration.access_actor_types` (for example `["User"]`).
5. For the first staff grant on an empty owned admin root, call `RecordingStudioAccessible.bootstrap_owner_access!(recording:, actor:)`. Use `grant_access` for later invites.
6. Run `rails g recording_studio:migrations` (or install the harden indexes migration) and `db:migrate` if upgrading from RecordingStudio 3.x.
7. Re-run `recording_studio_admin:admin_root` only if you want the updated generator template; otherwise apply the enablement change by hand.

## 1.2.0

### Added

- **Widget information tooltips**: widgets can define static or callable `info` text, resolved with the widget context and rendered as an accessible contextual tooltip.

## 1.1.0

### Added

- **Modal screen filters**: screens with filters now use a FlatPack modal filter control by default, including an active-filter count badge and a mobile form.
- **Configurable filter presentation**: `filter_presentation` supports `:auto`, `:inline`, and `:modal` layouts. Modal screens can keep a leading set of filters visible with `inline_count`.
- **Coordinated filter updates**: inline and modal filter forms preserve each other's active query values while refreshing the chart, table, and count Turbo frames.

### Changed

- Updated the FlatPack dependency to `~> 0.1.124`.
- Improved filter interactions to submit date ranges consistently and reset result frames before refreshed content arrives.

## 1.0.1

### Changed

- Updated `recording_studio` dependency from `v3.0.0` to `v3.0.2`.
- Default RecordingStudioAdmin engine sections and screens to RecordingStudio core's shared `recording_studio/default_layout`, while preserving global and per-surface `engine_layout` overrides for host apps.

## 1.0.0

### Added

- **RecordingStudioAdmin engine core**: a Rails mountable engine providing reusable, code-defined admin and reporting screens for Recording Studio.
- **Code-defined admin surfaces**: `Section`, `Screen`, `Widget`, `Filter`, and `Resource` APIs for defining admin interfaces entirely in Ruby.
- **Resolver layer**: `ScreenResolver` and `SectionResolver` that resolve definitions into renderable objects, supporting lazy resolution, context propagation, and widget variant selection.
- **Table rendering**: server-side column selection, sortable columns, pagination, row actions with URL safety enforcement, skeleton loading states, and export-button integration with `recording_studio_exportable`.
- **Chart rendering**: chart frame support including geo-chart integration with a world map SVG, country centroids, and Google Charts-compatible series/options helpers (`FlatPackGeoChartSupport`).
- **Widget system**: metric, chart, list, and progress widgets with compact and full view variants, async lazy-loading via Turbo frames and IntersectionObserver, and a `WidgetChangeSemantics` tone classifier.
- **Filter system**: date-range, select, and multi-select filters with proc-backed dynamic options, preset labels, and form auto-submit behavior via Stimulus.
- **Async widget loading**: configurable concurrent request limiting, retry logic, and lazy viewport detection (`AsyncWidgetsController` Stimulus controller).
- **Screen filter Stimulus controller**: manages date-range submit-on-click, Turbo Frame load/error handling, table skeleton toggling, and preset-label sync from hidden fields.
- **Admin access hardening**: configurable `authentication_method`, `authorization_method`, and `current_actor_method`; fail-closed with `401 Unauthorized` / `403 Forbidden`; private callback support; safe `Current.actor=` assignment.
- **Authorization**: `RecordingStudioAdmin::Authorization` module with `AuthorizationFailed` error, surface-level auth overrides, and `authorize_admin_action!` integration.
- **Admin action auditing**: `AdminActionAudit` concern and `AdminActionAudit` model for logging admin actions with actor, recording, and parameters.
- **Admin activity logs**: `AdminActivityLogsScreen`, `AdminActivityLogsSection`, `AdminActivityLogsWidget`, and `AdminActivityLogsSupport` providing built-in audit-trail screens.
- **Configuration**: `RecordingStudioAdmin.configure` block supporting `authentication_method`, `authorization_method`, `current_actor_method`, `default_mount_path`, `async_widgets` settings, and `blast_radius` risk limits.
- **Generators**:
  - `recording_studio_admin:install` — mounts the engine, validates `mount_path`, and writes an initializer with auth configuration.
  - `recording_studio_admin:admin_root` — scaffolds an editable admin root recordable with access controls.
  - `recording_studio_admin:resource` — generates admin CRUD screens with form, actions, and table configuration.
  - `recording_studio_admin:resource_form` — generates form partials for admin resources.
  - `recording_studio_admin:resource_action` — generates custom admin actions.
- **Registry**: centralized `RecordingStudioAdmin::Registry` for registering sections, screens, resources, and widgets with duplicate detection and lookup.
- **`AllowsAdminSections`**: mixin for host models to declare associated admin sections.
- **`BlastRadius`**: risk-assessment utility for admin actions.
- **Context/Period**: `Context` and `Period` value objects for time-bounded admin contexts with preset support.
- **`TableCellRenderer`**: centralized cell rendering with type-aware formatting and row-action URL safety.
- **`URLSafety`**: URL sanitization rules for row actions, ensuring only safe schemes and hosts.
- **`RecordingStudioAccessibleCompatibility`**: bridge for `recording_studio_accessible` integration, including avatar rendering.
- **`Surface`**: mount-point abstraction carrying auth configuration, context, and layout selection.
- **`Resource`**: resource definition API with fields, actions, and form configuration.
- **Dummy app**: admin summary page, four example screens (API Requests, Users, Admin Activity Logs, Export Logs), seed data, database migrations, and FlatPack-themed layouts.
- **View components and partials**: screen show, section index/show, widget frames, chart frames, table frames with Turbo, table count, table skeleton, and page shell layout.
- **JavaScript controllers**: `async_widgets_controller`, `screen_filters_controller` (Stimulus).
- **Geo chart helper**: `GeoChartHelper` with world map SVG asset, country centroids, and Google Charts geo-chart series/options normalization.
- **Widget rendering helper**: `WidgetRenderingHelper` with presenter integration, async frame helpers, and frame-ID generation.

### Changed

- **Namespace**: renamed the engine namespace across all files, modules, routes, and configuration.
- **Dependencies**: added `flat_pack ~> 0.1.103`, `recording_studio_accessible ~> 0.3`; pinned dev/test dependencies to `flat_pack`, `recording_studio`, `recording_studio_accessible`, and `recording_studio_exportable` from GitHub.
- **Routes**: replaced `HomeController#index` root with `SectionsController#index`; added RESTful routes for sections, screens, widgets, charts, tables, and table counts.
- **CI**: renamed the test database to `recording_studio_admin_test`.
- **RuboCop**: expanded exclusions for generated templates, resolvers, helpers, and large core files.
- **Rake test tasks**: added `bundle install` guard before dummy app test runs.
- **README**: rewritten from gem template docs to full RecordingStudioAdmin documentation covering quick start, admin root scaffolding, engine screens, and configuration.
- **Copilot instructions**: updated to reflect `RecordingStudioAdmin` conventions, FlatPack UI rules, and current test/repo patterns.

### Removed

- **Template-era infrastructure**: `ApplicationController`, `HomeController`, legacy initializer, rename script, private-gem migration notes, RecordingStudio v3 update summary docs, template services (`BaseService`, `ExampleService`), and template hooks.
