# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Spotlight Theater website - a Phoenix 1.8 application for a non-profit homeschool community theater in West Michigan. The site has public pages for visitors and an admin system for managing productions.

## Common Commands

```bash
# Development
mix setup              # Install deps, create DB, run migrations, build assets
mix phx.server         # Start dev server (localhost:4000)
mix test               # Run all tests
mix test path/to/test.exs:42  # Run single test at line
mix format             # Format code

# Database
mix ecto.migrate       # Run migrations
mix ecto.reset         # Drop, create, migrate, seed

# Admin Users (invite-only, no public registration)
mix create_user "Name" "email@example.com"  # Creates user, sends magic link

# Deployment
mix deploy production  # Deploy to production server
mix deploy.service production  # Update systemd service
mix deploy.nginx production    # Update nginx config
```

## Architecture

### Contexts
- `Spotlight.Accounts` - User authentication (magic link, no passwords required)
- `Spotlight.Productions` - Productions, Performances (show times), ProductionPhotos

### Key Schemas
- `Production` - Theater productions with status (draft/published/archived)
- `Performance` - Individual show times belonging to a production
- `ProductionPhoto` - Gallery photos with position ordering
- `User` - Admin users (name, email, magic link auth)

### Routes
- `/` - Public pages (PageController)
- `/admin/*` - Protected admin LiveViews (require authentication)
- `/users/log-in` - Magic link login (no registration route)

### Admin LiveViews
Located in `lib/spotlight_web/live/admin/`:
- `DashboardLive` - Admin home
- `ProductionLive.Index/Show` - Production CRUD
- `UserLive.Index` - User management with invite flow

### Styling
- Tailwind CSS 4 + daisyUI 5
- Site uses custom cream/teal color scheme
- Admin pages use explicit `text-gray-*` classes for contrast on cream background

## Deployment

Capistrano-style deployment via custom mix tasks to teagles.io server:
- Config in `config/deploy.exs`
- Build script: `build.sh`
- Systemd service: `deploy/spotlight.service`
- Nginx config: `deploy/nginx.conf` (includes apex→www redirect)

## Development Notes

- Local dev domain: `spotlight.test` (configured in `config/dev.exs`)
- Dev mailbox at `/dev/mailbox` for magic link emails
- LiveView socket must be in endpoint.ex for WebSocket/longpoll
