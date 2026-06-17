> **Repository Documentation**
> *   **Applies To:** RecordingStudioAdmin devcontainer and dummy app workflow
> *   **Last Updated:** June 17, 2026
>
> *Maintainers: Please update the date above when modifying this file.*

---

# GitHub Codespaces Setup

This document covers how the devcontainer is configured and how to work in GitHub Codespaces.

---

## Quick Start

1. **Create a Codespace** on this repository (click the green "Code" button → "Codespaces" → "Create codespace on main").
2. **Wait** for the container to build and the `postCreateCommand` to complete (3-5 minutes).
3. **Start the development server**:
   ```bash
   cd test/dummy
   bin/dev
   ```
4. **Open the app** – click the forwarded port 3000 in the "Ports" tab.
5. **Start from the dummy app home page** at `/` and use `/users/sign_in` or `/docs/install` as needed.

---

## What Runs Automatically

The `postCreateCommand` in `.devcontainer/devcontainer.json` executes:

```bash
git lfs install && \
npm install -g playwright && \
playwright install --with-deps && \
cd test/dummy && \
bundle install && \
bundle exec rails db:prepare && \
bundle exec rails tailwindcss:build
```

This:
- Installs Git LFS (if needed)
- Installs Playwright and its browser dependencies for browser-based checks
- Installs gem dependencies
- Prepares the PostgreSQL database (creates, migrates, seeds)
- Builds TailwindCSS assets

---

## Docker Compose Services

The devcontainer uses Docker Compose with three services defined in `.devcontainer/docker-compose.yml`:

| Service | Image | Port | Notes |
|---------|-------|------|-------|
| **db** | `postgres:16` | 5432 | UUID support via `pgcrypto`; volume `pgdata` |
| **redis** | `redis:7-alpine` | 6379 | Volume `redis_data` |
| **app** | Built from `.devcontainer/Dockerfile` | 3000 | Ruby 3.3 slim; mounts `/workspace` |

Health checks ensure dependent services are ready before Rails boots.

---

## Environment Variables

Set automatically inside the container:

| Variable | Value |
|----------|-------|
| `DB_HOST` | `db` |
| `DB_PORT` | `5432` |
| `DB_USER` | `postgres` |
| `DB_PASSWORD` | `postgres` |
| `DB_NAME` | `app_development` |
| `BUNDLE_PATH` | `/usr/local/bundle` |
| `REDIS_URL` | `redis://redis:6379/0` |
| `CODESPACES` | `true` |

---

## CSRF Protection

When `ENV["CODESPACES"] == "true"`:
- CSRF **origin check is relaxed** (avoids issues with GitHub's forwarded URLs).
- CSRF **authenticity tokens remain enabled** for security.

For best results, access your app consistently via:
- The Codespaces forwarded URL (`*.app.github.dev`), **or**
- `localhost:3000` (if port forwarding is set to local).

---

## Running the Server

Use `bin/dev` to start both Rails and the Tailwind watcher:

```bash
cd test/dummy
bin/dev
```

This runs Foreman with `Procfile.dev`:

```
web: bin/rails server -b 0.0.0.0
css: bin/rails tailwindcss:watch
```

Binding to `0.0.0.0` is required for Codespaces port forwarding.

---

## Port Forwarding

Codespaces forwards port `3000` for the dummy app and `5432` for PostgreSQL. Find them in the **Ports** tab.

Open the forwarded Rails app from the globe icon or from the command line with:

```bash
"$BROWSER" https://<your-forwarded-url>
```

If port 3000 is busy:

```bash
PORT=3001 bin/dev
```

---

## Rebuilding the Container

If you change `.devcontainer/` files:

1. Open the Command Palette (`Ctrl+Shift+P` / `Cmd+Shift+P`).
2. Run **Codespaces: Rebuild Container**.

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Container fails to start | Check Docker Compose logs in the terminal. |
| Database connection refused | Ensure the `db` service is healthy and the dummy app is using `DB_HOST=db`. |
| Tailwind not rebuilding | Restart `bin/dev` or run `bin/rails tailwindcss:build`. |
| `bin/dev` exits immediately | Remove a stale `test/dummy/tmp/pids/server.pid`; the dummy `bin/dev` script already cleans up dead PID files on startup. |
| Port already in use | Use a different port: `PORT=3001 bin/dev`. |

---

## Files Reference

| File | Purpose |
|------|---------|
| `.devcontainer/devcontainer.json` | Codespaces and post-create setup |
| `.devcontainer/docker-compose.yml` | Postgres, Redis, and app service definitions |
| `.devcontainer/Dockerfile` | Ruby container build |
| `test/dummy/Procfile.dev` | Foreman process definitions for Rails and Tailwind |
| `test/dummy/bin/dev` | Development startup script with Foreman install and stale PID cleanup |
