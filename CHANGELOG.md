# Changelog

## Unreleased

## 2.7.2 - 2026-10-28

### Changed

- Stop tracking SimpleCov output under `coverage/` and `test/dummy/coverage/`. `coverage/` is gitignored.
- Remove the dummy app's nested GitHub Actions workflow.
- CI Postgres and `DATABASE_URL` use `recording_studio_admin_test`, matching the Rakefile.
- Delete `test/rename_verification_test.rb` (it still asserted version `1.0.1`).
- Delete leftover gem-template docs under `docs/gem_template/` and Copilot agents under `.github/agents/`.
- Codespaces setup script points at `/admin` instead of `/gem_template`.
- Gemspec homepage, source, and changelog URLs use `https://github.com/bowerbird-app/RecordingStudio_admin`.
- README requirements match the gemspec and Gemfile (including Logs `>= 0.4.1, < 1.0` and development pin `v0.7.0`).
- Dummy export tests skip with an explicit "dummy does not include recording_studio_exportable" message and assert that omission. CSV export still needs `recording_studio_exportable`; this release does not add that gem.
- Remove the unused FlatPack `:geo` scatter/centroid patch: `FlatPackGeoChartSupport`, `recording_studio_flatpack_geo_series`, `recording_studio_flatpack_geo_options`, `recording_studio_flatpack_geo_container_style`, `COUNTRY_CENTROIDS`, and `world_map_light.svg`. Admin `:geo` charts are per-country (ISO2 + count) and still render through FlatPack `:geochart`.

## 2.7.1 - 2026-10-27

### Fixed

- Compact widgets stack the title above the metric. The mini chart sits in a fixed 104px box with `overflow-hidden`, so a gauge percent and a bar no longer paint over the title.
- Compact gauge charts hide the arc's center value. The metric already shows that number.
- Compact cards use `min-h-28` and grow with the title instead of clipping at `max-h-28`.
- A line or area chart with a single point draws a marker. Apex does not stroke a path through one point, so the chart no longer looks empty.
- Dummy Tailwind `@source` entries for this engine are directories, including `lib` and `app/javascript`. The install generator points at those directories too.
- Full widget cards share a fixed `h-[26rem]` height. Charts inside them are 200px tall. A full list shows the first 5 items.

### Upgrade notes

- Rebuild Tailwind after bumping. If you added the install-generator `@source` lines by hand, point them at `recording_studio_admin` `app/views`, `app/helpers`, `app/javascript`, and `lib` directories.
- See [docs/UPGRADING.md](docs/UPGRADING.md#upgrading-to-271).

## 2.7.0 - 2026-10-27

### Changed

- Requires RecordingStudio `>= 6.1.0` and Flatpack `>= 0.1.315`. Development and dummy Gemfiles pin RecordingStudio tag `v6.1.0` and Flatpack commit `1fcbafe94f8eb118f0a22182f63f5110fcc97a56` (`0.1.319`). `view_component` is `>= 4.14, < 5` (`4.19.0`).
- Accessible pin is `v0.21.0`. Trashable pin is `v0.12.0`. Logs stays `v0.7.0`. Metrics stays `v0.6.1`. Dummy root switchable stays `v0.8.0`.
- `config.engine_layout` and `surface.engine_layout` are `config.layout` and `surface.layout`.
- Layout resolution is the surface value when it is not `nil`, then the gem `layout`, then `RecordingStudio.configuration.layout`, then `"recording_studio/default_layout"`. `false` skips the layout. A callable must be `call(controller:)`.
- Engine controllers use `recording_studio_layout`. Section and screen headings are `content_for :title` and `:subtitle`. Back and close use `flat_pack_page_nav`. Actions use `register_page_nav`. Avatars use `recording_studio_page_nav_right`.
- The dummy Tailwind sheet no longer re-declares `--color-fp-*` or `@theme inline`. `tailwindcss:build` links the installed FlatPack, Recording Studio, Accessible, and root switchable gems into `app/assets/tailwind/gem_sources` and scans their components, helpers, and views. The install generator no longer injects the theme bridge.

### Upgrade notes

- Rename `engine_layout` to `layout`. Replace `RecordingStudio::UsesDefaultLayout` with `recording_studio_layout`.
- Move page headings out of the view body when the page uses the default layout. Register actions with `register_page_nav`.
- Load the three Flatpack stylesheets before Tailwind.
- See [docs/UPGRADING.md](docs/UPGRADING.md#upgrading-to-270).

## 2.6.2 - 2026-10-22

### Changed

- Development and dummy Gemfiles pin `recording_studio_logs` to GitHub tag `v0.7.0` and `recording_studio_metrics` to `v0.6.1`. No runtime code change.

## 2.6.1 - 2026-10-22

### Changed

- `recording_studio_logs` `>= 0.4.1, < 1.0` (CI tested with 0.5.0). No code change.

## 2.6.0 - 2026-10-21

### Added

- `recording_studio_logs` (`>= 0.4.1, < 0.6`). Development and dummy Gemfiles pin GitHub tag `v0.5.0`.
- RecordingStudioLogs registration for the host `admin_audit_logs` table (`partition_interval: nil`, `root_column: :root_recording_id`, retention `:indefinite`). No summary or aggregate tables.
- `root_recording_id` on `admin_audit_logs`, backfilled from `access_recording_id` through `recording_studio_recordings`. New inserts stamp it. Existing rows stay in the same unpartitioned table.
- `config.logs_retention` (default `:indefinite`). Registration always uses `:indefinite` because RS_Logs does not clean a log that has no summaries.
- `bin/rails generate recording_studio_admin:logs` for existing hosts (adds `root_recording_id` only).

### Upgrade notes

- Bump to `2.6.0`. Pin `recording_studio_logs` to GitHub tag `v0.5.0`.
- Run `bin/rails generate recording_studio_logs:migrations` if Logs run tables are not already present, then `recording_studio_admin:logs` (existing hosts) and `db:migrate`.
- Leave `config.logs_retention` as `:indefinite`. Do not schedule Logs partition or retention jobs for this table.
- See [docs/UPGRADING.md](docs/UPGRADING.md#upgrading-to-260).

## 2.5.1 - 2026-10-20

### Changed

- The built-in Admin activity overview widget stays on the Admin activity
  logs **section** and is no longer attached to the `admin_activity_logs`
  screen.
- Date range and Group by on that screen sit inline above the content.
  Outcome, Resource key, and table search stay in the filter modal.
- The section's "View admin activity logs" link remains non-primary
  (`style: :secondary`).

### Upgrade notes

- If a host copied the overview widget onto `/admin/screens/admin_activity_logs`,
  remove that `widget` line so the card lives only on the section.
- See [docs/UPGRADING.md](docs/UPGRADING.md#upgrading-to-251).

## 2.5.0 - 2026-10-20

### Changed

- `AdminActivityLogsSupport.date_series` now returns every hour/day/week/month/year
  bucket in the selected date range, including buckets with a count of `0`, in
  order. Screens that already call this helper (MCP Usage, AI, agent runs, and
  admin activity logs) pick up the filled series with no caller changes.
- Ranges that would produce more than `1_000` buckets (for example hour grouping
  over a year) keep the previous sparse series so charts stay bounded.

### Upgrade notes

- Chart series from `date_series` can include extra `{ x:, y: 0 }` points for
  empty buckets. The method signature is unchanged.
- See [docs/UPGRADING.md](docs/UPGRADING.md#upgrading-to-250).

## 2.4.0 - 2026-10-19

### Fixed

- Admin activity logs and other screens render with Flatpack `0.1.254`.
  Card `style: :outlined` was removed in Flatpack `0.1.237`. Those cards now
  use `border: :strong` (surface fill, 2px border), which matches the old
  outlined look.

### Changed

- Engine, dummy, and gemspec pin `flat_pack` to `~> 0.1.254` (git tag
  `v0.1.254`).

### Upgrade notes

- Bump the host `flat_pack` pin to git tag `v0.1.254` or newer. Admin
  `2.4.0` requires `flat_pack ~> 0.1.254`.
- Host cards that still pass `style: :outlined` need `border: :strong`.
  Colour styles are `:default`, `:shaded`, `:brand`, `:brand_subtle`, and
  `:gradient`.
- See [docs/UPGRADING.md](docs/UPGRADING.md#upgrading-to-240).

## 2.3.3 - 2026-10-16

### Changed

- Dummy and engine Gemfiles pin RecordingStudioTrashable to `v0.11.0`
  (`436cbb8`). Trashable 0.11 requires RecordingStudio `~> 4.7`, so those
  Gemfiles also pin RecordingStudio to `v4.7.0`.

## 2.3.2 - 2026-10-14

### Changed

- Dummy and engine Gemfiles pin RecordingStudio Accessible to `v0.18.0`.

## 2.3.1 - 2026-10-14

### Changed

- Dummy and engine Gemfiles pin RecordingStudio Accessible to `v0.17.0` and
  RecordingStudio to `v4.6.0`.

## 2.3.0 - 2026-10-13

### Added

- Dependency on RecordingStudioTrashable `~> 0.10` (dev/test pin `v0.10.0`,
  `require: false`) loaded only via `recording_studio_trashable/query`
- Parity tests for kept-SQL lookups under a host
  `default_scope { where.not(trashed_at: nil) }`, plus a surface test that
  Trashable's engine/importmap/capability/metrics do not load

### Changed

- `SectionRecordingResolver` finds kept section recordings with
  `unscoped.where(recording_studio_trashable_kept_sql)` when Trashable query
  helpers and `trashed_at` exist (same `unscoped` base as main; no `_active`
  unscope); otherwise keeps `unscoped.find_by(..., trashed_at: nil)`
- Admin-root examples, dummy initializer, workspace stats, and seeds use
  `where(recording_studio_trashable_kept_sql)` on the same relation base main
  used (no added `unscoped`, no `_active`)

### Upgrade notes

- Add `recording_studio_trashable` (`~> 0.10`, git tag `v0.10.0`,
  `require: false`). Admin requires `recording_studio_trashable/query` only —
  not the full Trashable engine.
- Prefer `where(...kept_sql)` over `recording_studio_trashable_active` for
  former `trashed_at: nil` filters so host `trashed_at` default scopes stay
  intact.
- See [docs/UPGRADING.md](docs/UPGRADING.md#upgrading-to-230).

## 2.2.0 - 2026-10-13

### Added

- English Rails I18n keys for sections search group headings
  (`Sections` / `Screens` / `In %{title}`) and screen filter date-preset
  labels under `recording_studio.admin`
- Dummy host override for `screens.filters.date_presets.last_year` as a
  real boot-order guard (`test/dummy/config/locales`)

### Changed

- Sections search group titles and screen-filter date-preset labels resolve
  through `t(...)` / Stimulus JSON (English output unchanged)
- Existing view `t(...)` calls pass English `default:` values

### Upgrade notes

- No migration or host code change is required for English.
- To translate or override the new strings, add keys under
  `recording_studio.admin.sections.index.search_groups` and
  `recording_studio.admin.screens.filters.date_presets` in the host's
  locale files.
- See [docs/UPGRADING.md](docs/UPGRADING.md#upgrading-to-220).

## 2.1.0 - 2026-10-09

### Added

- English Rails I18n keys for static interface copy in the gem's own views
  and partials (`config/locales/en.yml` under `recording_studio.admin`)

### Changed

- Static chrome in sections, screens (filters/table), widgets, and page_nav
  resolves through `t(...)` (English output unchanged)

### Upgrade notes

- No migration or host code change is required for English.
- To translate or override the defaults, add keys under
  `recording_studio.admin` in the host's locale files.
- See [docs/UPGRADING.md](docs/UPGRADING.md#upgrading-to-210).

## 2.0.7 - 2026-10-08

### Fixed

- Version constant now matches the git tag. It was stuck at `2.0.2` across
  tags `v2.0.2` through `v2.0.6`.

### Changed

- Includes the RecordingStudio `v4.3.0` pin bump already on main (#13).

## 2.0.4 - 2026-10-05

### Changed

- Dummy and engine Gemfiles pin RecordingStudio Accessible to `v0.11.1`.
- Dummy installs Accessible `0.8`–`0.11` migrations (dependent grants,
  invitations, string roles). Seeds and tests grant access through
  `bootstrap_owner_access!` and `grant_access` only.

## 2.0.3 - 2026-10-02

### Changed

- Dummy and engine Gemfiles pin RecordingStudio to `v4.2.2`.
- Dummy admin root PageNav assertion matches RecordingStudio `4.2.2` layout
  (`anchor_href`). Close still needs FlatPack `>= 0.1.197`; this pin keeps
  FlatPack at `v0.1.129`.

## 2.0.2

Cloud Agent install no longer fails a warm environment rebuild. Skills still
fetch at Build.

### Added

- Track `.cursor/install.sh`, `.cursor/fetch-skills.sh`, `.cursor/start.sh`,
  and `.cursor/environment.json` so Cloud Agent Builds match Billing 0.9.13.

### Fixed

- `.cursor/install.sh` skips apt, ruby-build, db:prepare, and tailwind when
  Ruby, bundle, and Postgres are already usable. A skippable provision
  failure no longer fails the Build. Fetch-skills always runs last.

### Upgrade Notes

See [docs/UPGRADING.md](docs/UPGRADING.md#upgrading-to-202). No host or schema
changes. Rebuild the Cloud Agent environment with Draft off so Build loads
the pack.

## 2.0.1

### Fixed

- Loading a screen chart, table, table count, or widget endpoint as a whole page (typed URL, bookmark, refresh, or a new tab) no longer renders a bare unstyled fragment. Those page loads now redirect to the screen or section page that owns the frame, keeping the current query (sort, filters, page, columns). Turbo Frame and XHR fetches are unchanged.

### Documentation

- README documents the frame endpoints under "Routing and surfaces", including how a page load is told apart from a frame fetch.

### Upgrade Notes

See [docs/UPGRADING.md](docs/UPGRADING.md#upgrading-to-201). Drop-in patch release: no configuration, API, or dependency changes. Custom JavaScript that fetches the frame endpoints keeps receiving the fragment.

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
- Dummy pins: RecordingStudio `v4.1.0`, Accessible `v0.6.1`, Root Switchable `v0.5.0`, FlatPack `v0.1.129`.
- Dummy Tailwind sources aligned with sibling dummies so FlatPack / engine classes are included in the build.
- Dummy Accessible initializer sets `access_actor_types = ["User"]`.

### Removed

- Dummy no longer ships `recording_studio_exportable`. Exportable `0.2.0` requires RecordingStudio `~> 4.2`; Admin still gates export UI behind `defined?(RecordingStudioExportable)`.

### Upgrade Notes

See [docs/UPGRADING.md](docs/UPGRADING.md#upgrading-to-200). Summary:

1. Upgrade RecordingStudio to `~> 4.1` and Accessible to `~> 0.6` (tested with Accessible `v0.6.1`) and FlatPack to `~> 0.1.129` before installing Admin `2.0.0`.
2. Replace `AllowsAccessibleChildren` / `recording_studio_accessible_children` with `RecordingStudio.enable_capability(:accessible, on: self)`.
3. Keep AdminRoot owned (`shared: false`). Do not make the admin root a shared root.
4. Configure `access_actor_types` (for example `["User"]`).
5. First staff on an empty owned admin root: `RecordingStudioAccessible.bootstrap_owner_access!(recording:, actor:)`. Later invites: `grant_access`.
6. From RecordingStudio 3.x, run `rails g recording_studio:migrations` and `db:migrate`.
7. Billing (`~> 1.1.0`), API dummy (`1.1.0`), and Notifications dummy (`1.0.0`) stay on Admin 1.x until those gems bump. Webhooks tracks this repo untagged and must pin `1.2.0` or upgrade its RS/Accessible stack before `bundle update`. Users 0.1 does not need this release; Users Phase 6 does.

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

[Unreleased]: https://github.com/bowerbird-app/RecordingStudio_admin/compare/v2.6.2...HEAD
[2.6.2]: https://github.com/bowerbird-app/RecordingStudio_admin/compare/v2.6.1...v2.6.2
[2.6.1]: https://github.com/bowerbird-app/RecordingStudio_admin/compare/v2.6.0...v2.6.1
[2.6.0]: https://github.com/bowerbird-app/RecordingStudio_admin/compare/v2.5.1...v2.6.0
[2.5.1]: https://github.com/bowerbird-app/RecordingStudio_admin/compare/v2.5.0...v2.5.1
[2.5.0]: https://github.com/bowerbird-app/RecordingStudio_admin/compare/v2.4.0...v2.5.0
[2.4.0]: https://github.com/bowerbird-app/RecordingStudio_admin/compare/v2.3.3...v2.4.0
[2.3.3]: https://github.com/bowerbird-app/RecordingStudio_admin/compare/v2.3.2...v2.3.3
[2.3.2]: https://github.com/bowerbird-app/RecordingStudio_admin/compare/v2.3.1...v2.3.2
[2.3.1]: https://github.com/bowerbird-app/RecordingStudio_admin/compare/v2.3.0...v2.3.1
[2.3.0]: https://github.com/bowerbird-app/RecordingStudio_admin/compare/v2.2.0...v2.3.0
[2.2.0]: https://github.com/bowerbird-app/RecordingStudio_admin/compare/v2.1.0...v2.2.0
[2.0.4]: https://github.com/bowerbird-app/RecordingStudio_admin/compare/v2.0.3...v2.0.4
[2.0.3]: https://github.com/bowerbird-app/RecordingStudio_admin/compare/v2.0.2...v2.0.3
